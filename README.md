# Artifact for "Practical Fault Detection in Puppet Programs" (ICSE'20)

This repository contains instructions
and scripts to re-run the evaluation
of the ICSE'20 paper
"Practical Fault Detection in Puppet Programs".

A pre-print of the paper is available [here](https://dimitro.gr/assets/papers/SMS20.pdf).


# Requirements

* A Unix-like operating system.

* An installation of Docker (Please, follow the instructions from
  the official [documentation](https://docs.docker.com/install/)).

* At least 35GB of available disk space.


# Setup

The tool used in our paper
(which we call `FSMove`) is available as
open-source software under
the GNU General Public License v3.0.

Repository URL: https://github.com/AUEB-BALab/FSMove

Clone `FSMove`:

```bash
git clone https://github.com/AUEB-BALab/fsmove
cd fsmove
```

## Docker Image

To facilitate the use of `FSMove`,
we provide a `Dockerfile` that builds an image
with the necessary environment for
applying and analyzing Puppet modules.
This image consists of the following elements:

* An installation of `FSMove`.
  The image installs the OCaml compiler
  (version 4.0.5) and all the packages required for
  building `FSMove` from source. 
* An installation of [Puppet](https://puppet.com/).
* An installation of [strace](https://strace.io/).
* A user named `fsmove` with `sudo` privileges.

To build the Docker image (`fsmove`), run a command of
the form
```bash
docker build -t fsmove --build-arg IMAGE_NAME=<base-image> .
```
where `<base-image>` refers to the base image
from which we set up the environment.
In our evaluation, we ran Puppet manifests on Debian Stretch,
so we used `debian:stretch` as the base image.
So please run the following command:
```bash
docker build -t fsmove --build-arg IMAGE_NAME=debian:stretch .
```
This will take roughly 10-15 minutes.

# Getting Started

## Navigating through the Docker Image

Before running our examples,
let's explore the contents of our freshly-created Docker
image.
Run the following command to create a new container.
```bash
docker run -ti --rm  --security-opt seccomp:unconfined fsmove
```
After executing the command,
you will be able to enter the home directory
(i.e., `/home/fsmove`) of the `fsmove` user.
This directory contains the `fsmove_src`
where the source code of our tool is stored.

To build `FSMove` on your own, run
```bash
fsmove@606771a763fd:~$ cd ~/fsmove_src
fsmove@606771a763fd:~$ dune clean && dune build -p fsmove
```

For running tests, execute
```bash
fsmove@606771a763fd:~$ dune runtest
```
This will produce something that is similar to the following
```bash
fsmove@606771a763fd:~$ dune runtest
run_tests alias fsmove_src/test/runtest
................................................................
Ran: 64 tests in: 0.11 seconds.
OK
```

After examining the source code
of `FSMove`, you can exit from the Docker container
by running
```bash
fsmove@606771a763fd:~$ exit
```

## Running the first examples

### Example1: Setup a MySQL DB

Inside the `example/` directory of this repository,
there is one simple Puppet script,
namely `example/mysql_db.pp`.
This Puppet script
installs the `mysql-common` and `mysql-server` packages,
configures the file `/etc/mysql/my.cnf`
wit the desired contents,
and initializes the MySQL database by
running the `sudo mysqld --initialize` command.
In particular,
the contents of `example/mysql_db.pp` are
```puppet
$packages = ['mysql-common','mysql-server']
package {$packages:
  ensure => installed
}

$my_cnf_contents = "[mysqld]
!includedir /etc/mysql/mariadb.conf.d/
!includedir /etc/mysql/conf.d/
innodb_buffer_pool_size=7GB
innodb_log_file_size=256M
key_buffer_size=5GB
log_error=/var/log/mysql/error.log"

file {'/etc/mysql/my.cnf':
  ensure  => 'file',
  content => $my_cnf_contents,
  require => [Package['mysql-server'], Package['mysql-common']]
}

exec {'Initialize MySQL DB':
  command => 'sudo mysqld --initialize',
  path    => '/bin:/usr/bin',
  require => [Package['mysql-server'], Package['mysql-common']]
}
```
The Puppet script above contains a fault
that we are going to detect using `FSMove`.
We will use the Docker image created
in a previous step in order to run
and analyze this Puppet script.
To do so,
run the following command
```bash
docker run -ti --rm  \
  --security-opt seccomp:unconfined \
  -v $(pwd)/examples/mysql_db.pp:/home/fsmove/init.pp \
  -v "$(pwd)"/out:/home/fsmove/data fsmove \
  -m mysql-db -i no -s
```
This command will execute the `example/mysql_db.pp` script
inside a Docker container through `FSMove`.
Our tool will analyze its execution trace,
and will finally report the detected faults.
This command takes around 1-2 minutes.

Below, we provide the details of
our command.

* `--security-opt` (Docker option): This option
  enables system call tracing
  inside the Docker container.
* `-v` (Docker option): Through the option `-v`,
  we mount two local files inside the container.
  First, we mount the script located
  in `$(pwd)/example/mysql_db.pp`
  into `/home/fsmove/init.pp` that
  corresponds to the location
  where the container tries to find
  the entrypoint Puppet script
  that we want to analyze.
  Second, we mount the directory `$(pwd)/out`
  into `/home/fsmove/data`.
  All the analysis results
  produced during the execution of this container
  are stored in the local directory`$(pwd)/out`.
* `-m` (Image option): This option takes the name
  of the module as it is specified in [Forge API](https://forge.puppet.com/).
  In this example, we provide an arbitrary module name,
  because the provided Puppet script does not exist in Forge API.
* `-i` (Image option): This option indicates if we must install
  the Puppet module from Forge API before proceeding to the analysis.
  Available options are `no`, `latest`, and `<version-number>`.
  In this example, we provided `-i no`,
  because this Puppet script does not appear in Forge API.
  Therefore, we do not need to install it.
* `-s` (Image option): This flag indicates that we must monitor
  the execution of Puppet script using `FSMove`.
  Absence of this flag applies Puppet script without monitoring.

After the aforementioned command exits,
you can examine the results of the analysis
inside the `$(pwd)/out/` directory.
In particular,
the command produces the following six (6) files:
* `mysql-db.json`: the compiled catalog of the corresponding Puppet module.
* `mysql-db.strace`: a system call trace produced by `strace`.
* `mysql-db.size`: the size of system call trace (in bytes)
* `application.time`: time spent to apply the module.
* `mysql-db.times`: time spent on trace analysis
* `mysql-db.faults`: faults detected by `FSMove`.


The contents of `mysql-db.faults` are similar to the following:
```bash
Start executing manifest /home/fsmove/init.pp ...
Missing Ordering Relationships:
===============================
Number of MOR: 1
Pairs:
  * File[/etc/mysql/my.cnf]: /etc/puppet/code/environments/production/manifests/init.pp: 14
  * Exec[Initialize MySQL DB]: /etc/puppet/code/environments/production/manifests/init.pp: 20 =>
      Conflict on 1 resources:
      - /etc/mysql/my.cnf: Produced by File[/etc/mysql/my.cnf] ( rename at line 169402 ) and Consumed by Exec[Initialize MySQL DB] ( open at line 169990 )

Analysis time: 55.138767004
```
In particular,
`FSMove` detects one missing ordering relationship
between the Puppet resource `File[/etc/mysql/my.cnf]`
(defined at line 14 of the given Puppet script),
and the resource `Exec[Initialize MySQL DB]`
(defined at line 20).
These resources are conflicting on one file,
but there is no dependency between them.
Specifically,
`File[/etc/mysql/my.cnf]` produces the file `/etc/mysql/my.cnf`,
while `Exec[Initialize MySQL DB]` consumes the same file.
For debugging purposes,
`FSMove` also reports the system call
and the corresponding line in `mysql-db.strace`.
For example, `( rename at line 169402 )`
indicates that `File[/etc/mysql/my.cnf]` produced
`/etc/mysql/my.cnf` by calling the `rename()` system call
as it appears at line 169402 of
the corresponding `strace` file.
For more details about this fault,
see the first motivating example
described in our paper (Section 2).

### Example2: Running and analyzing a real-world Puppet module

It's time to run and analyze a real-world Puppet module,
namely [alertlogic-al_agents](https://forge.puppet.com/alertlogic/al_agents),
using `FSMove`.
Again,
we will use our Docker image `fsmove`
to spawn a fresh Puppet environment.
Run the following command
```bash
docker run -ti --rm  \
  --security-opt seccomp:unconfined \
  -v "$(pwd)"/out:/home/fsmove/data fsmove \
  -m alertlogic-al_agents -i 0.2.0 -s
```
Notice that this time,
we provided the option `-i 0.2.0`,
as we need to install the `alertlogic-al_agents` module
(version 0.2.0) in the system,
before proceeding to the analysis.
As already discussed,
this module is taken
from [Forge API](https://forge.puppet.com/alertlogic/al_agents).
Also,
notice that this time
we did not mount any file into
`/home/fsmove/init.pp`,
because the container creates it automatically
after the installation of the `alertlogic-al_agents` module.

After the completion of the command above
(it takes 1-2 minutes),
we are now ready to examine the fault detection results
stored inside the `$(pwd)/out/` directory.
The contents of `out/alertlogic-al_agents.faults` file
are
```bash
Start executing manifest /home/fsmove/init.pp ...
Missing Ordering Relationships:
===============================
Number of MOR: 1
Pairs:
  * Exec[download]: /etc/puppet/code/environments/production/modules/al_agents/manifests/install.pp: 7
  * Package[al-agent]: /etc/puppet/code/environments/production/modules/al_agents/manifests/install.pp: 24 => 
      Conflict on 1 resources:
      - /tmp/al-agent: Produced by Exec[download] ( open at line 46027 ) and Consumed by Package[al-agent] ( open at line 54187 )

Analysis time: 23.1748681068
```
Notably,
`FSMove` detected one ordering violation,
between `Exec[download]` and `Package[al-agent]` resources.
For more details about this fault,
see Section 6.3.1 of our paper.

# Benchmarks

This repository also includes one directory:
`benchmarks/`.
The directory includes
34 sub-directories representing
the Puppet modules listed in Table 1 of our paper.
Each directory contains the `init.pp` file
corresponding to the entrypoint script for executing the
module inside the container,
and the `params.txt` file contains parameters for
setting up the environment properly.
For example,
the following `params.txt` shows that
the script needs to install `albatrossflavour-os_patching`
(version 0.11.2) inside
the `/home/fsmove/.puppet/etc/code/modules` directory.
```bash
version: 0.11.2
modulepath: /home/fsmove/.puppet/etc/code/modules
modulename: albatrossflavour-os_patching
```
Some modules optionally contain a custom script
named `pre-script.sh`.
In this case,
the container runs the provided script,
before the execution and analysis of
the corresponding Puppet module.

To run the benchmarks, execute the following script:
```bash
./scripts/run-benchmarks.sh
```
This script will take 20-50 minutes depending on your machine.
It produces a directory
(namely `benchmark-results`)
that contains the analysis results
for every benchmark.
Each sub-directory contains the six files produced from the analysis
of the corresponding module.
The script also generates the `benchmark-results/faults.csv`
file that shows the occurrence of each fault type
in every benchmark.

If you want to run a specific benchmark
(e.g., albatrossflavour-os_patching),
then simply run
```
./scripts/run-benchamrks.sh albatrossflavour-os_patching
```

# Trace Dataset

For further offline trace analysis,
we also provide the traces and compiled catalogs
stemming from the execution of all Puppet modules
examined in our evaluation.
Dataset URL: https://doi.org/10.5281/zenodo.3626750

You can download the dataset of traces
as follows
```bash
wget -O traces.tar.gz "https://zenodo.org/record/3626750/files/traces.tar.gz?download=1"
tar -xvf traces.tar.gz
```

To analyze all traces using `FSMove`,
create a container,
and enter container's shell
by running.
```bash
docker run -ti --rm  \
  --security-opt seccomp:unconfined \
  -v $(pwd)/scripts:/home/fsmove/scripts \
  -v $(pwd)/traces:/home/fsmove/traces fsmove
```
Then, run the following command from the newly-created container
```bash
fsmove@b7b5bca1a9df:~$ ./scripts/analyze-traces.sh traces
```
When this script terminates
(roughly 10-20 minutes),
you can exit container and
inspect the analysis results
stored in `traces/` directory.
The script also generates the `traces/faults.csv` file
which gives a summary of fault detection results.
