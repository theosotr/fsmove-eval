#! /bin/bash

set -e
fsmove_home=/home/fsmove


analyze_module() {
    puppet_file=
    pre_script=
    trace_dir=$(realpath $1)
    docker_image=$2
    modulepath=$3
    install_module=$4
    with_strace=$5
    timeout=$6
    module=$7
    OPTIND=8

    while getopts "p:s:" opt; do

      case "$opt" in
        p)  puppet_file=$OPTARG
            ;;
        s)  pre_script=$OPTARG
            ;;
        esac
    done
    shift $(($OPTIND - 1));

    module_dir=$trace_dir/$module

    if [ -d "$module_dir" ]; then
        echo "Ignoring module $module, directory already exists"
        exit 0
    fi

    mkdir $module_dir
    module_basename="$(cut -d '-' -f2 <<< "$module")"

    if [ -z "$puppet_file" ]; then
        # Create a puppet file to invoke the module.
        echo "class {'$module_basename': }" > .init.pp
        init_file=$(realpath .init.pp)
    else
        init_file=$(realpath $puppet_file)
    fi

    base_cmd="sudo docker run --name $module_basename\
        -v $module_dir:$fsmove_home/data \
        -v $init_file:$fsmove_home/init.pp \
        --security-opt seccomp:unconfined"
    container_cmd="$docker_image \
        -m $module \
        -k 10 \
        -p $modulepath \
        -i '$install_module' \
        -t $timeout \
        -s"
    container_cmd="$container_cmd"

    if [ -z "$pre_script" ]; then
        cmd="$base_cmd $container_cmd"
    else
        # Run a script before running the puppet code.
        pre_script=$(realpath $pre_script)
        cmd="$base_cmd -v $pre_script:$fsmove_home/pre-script.sh $container_cmd"
    fi

    set +e

    echo "Executing $module..."
    eval $cmd

    if [ $? -eq 1  ]; then
        rm -r $module_dir
        echo "Cannot trigger module $module" >> ./warnings.txt
    fi

    sudo docker rm $module_basename
}


analyze_all()
{
    trace_dir=$1
    docker_image=$2
    modulepath=$3
    install_module=$4
    module_file=$5

    while IFS= read module
    do
        analyze_module "$trace_dir" \
            "$docker_image" \
            "$modulepath" \
            "$install_module" \
            "$module"
    done < "$module_file"
    exit 0
}


install_module='no'
with_strace=1
timeout=6
while getopts "t:i:m:f:rw:" opt; do
  case "$opt" in
    t)  trace_dir=$OPTARG
        ;;
    i)  docker_image=$OPTARG
        ;;
    m)  modulepath=$OPTARG
        ;;
    f)  install_module=$OPTARG
        ;;
    r)  with_strace=0
        ;;
    w)  timeout=$OPTARG
        ;;
    esac
done
shift $(($OPTIND - 1));


cat /dev/null > ./warnings.txt

if [ -z $trace_dir ]; then
    echo "-t option is unspecified"
fi

if [ -z $docker_image ]; then
    echo "You have to specify a docker image with -i"
fi

if [ -z $modulepath ]; then
    modulepath=$fsmove_home/.puppet/etc/code/modules
fi

module=$1
if [ -z $module ]; then
    echo "You have to specify a puppet module name"
fi


shift
echo $module
if [ "$module" == "all" ]; then
    analyze_all $trace_dir \
        $docker_image \
        $modulepath \
        $install_module \
        $with_strace \
        $timeout \
        "$@"
else
    analyze_module $trace_dir \
        $docker_image \
        $modulepath \
        $install_module \
        $with_strace \
        $timeout \
        $module \
        "$@"
fi
