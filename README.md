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
(namely, `FSMove`) is released as
an open-source software under
the GNU General Public License v3.0.

Repository URL: https://github.com/AUEB-BALab/FSMove

Clone `FSMove`

```bash
git clone https://github.com/AUEB-BALab/FSMove
cd FSMove
```

## Docker Image

To facilitate the usage of `FSMove`,
we provide a `Dockerfile` that builds an image
with the necessary environment for
applying and analyzing Puppet modules.
This image consists of the following:

* An installation of `FSMove`.
  To do so, the image installs the OCaml 4.05 compiler
  and all the packages required for
  building `FSMove` from source. 
* An installation of [Puppet](https://puppet.com/).
* An installation of [strace](https://strace.io/).
* A user named `fsmove` with `sudo` privileges.



To build the Docker image (i.e., `fsmove`), run a command of
the form
```bash
docker build -t fsmove --build-arg IMAGE_NAME=<base-image> .
```
where `<base-image>` refers to the base image
used to set up the environment.
In our evaluation, we ran Puppet manifests on Debian Stretch,
so use we `debian:stretch` as the base image.
So run

```bash
docker build -t fsmove --build-arg IMAGE_NAME=debian:stretch .
```
This will take roughly 10-15 minutes.

# Getting Started

## Navigating Docker Image

Before running our first examples,
let's explore the contents of our freshly-created Docker
image.
Run the following command to get into the image's shell.

```bash
docker run -ti --rm  --security-opt seccomp:unconfined fsmove
```
After this, you will enter the home directory
(i.e., `/home/fsmove`) of the `fsmove` user.
This directory contains the `fsmove_src`
where the source code of our tool is stored.

To build `FSMove` on your own, run
```bash
cd fsmove_src
dune clean && dune build -p fsmove
```

For running tests, execute
```bash
dune runtest
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
exit
```

## Running first examples

Inside the `examples/` directory of this repository,
there are two simple Puppet scripts.

### Setup a MySQL DB

The first Puppet script (`examples/mysql_db.pp`),
installs the `mysql-common` and `mysql-server` packages,
configures the file `/etc/mysql/my.cnf`,
and initializes the MySQL database by
running the `sudo mysqld --initialize` command.

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
run the following command.
```bash
docker run -ti --rm  --security-opt seccomp:unconfined -v $(pwd)/examples/mysql_db.pp:/home/fsmove/init.pp -v "$(pwd)"/out:/home/fsmove/data fsmove -m mysql-db -i no -s
```
This command will execute our Puppet script
through `FSMove` inside a Docker container.
`FSMove` will analyze its execution trace,
and will finally report the detected faults.
After completing this process (it takes around 1-2 minutes),
the container will exit.

Below, we provide the details of
our command.

* `--security-opt` (Docker option): This option
  enables system call tracing
  inside the Docker container.
* `-v` (Docker option): Through the option `-v`,
  we mount two local files inside container.
  First, we mount the script located
  in `$(pwd)/examples/mysql_db.pp`
  into `/home/fsmove/init.pp` that
  corresponds to the location of
  where our container tries to find
  the entrypoint Puppet script
  that we want to analyze.
  Second, we mount the directory `$(pwd)/out`
  into `/home/fsmove/data`.
  All the results of the analysis
  produced during the execution of container
  are stored in the local directory`$(pwd)/out`.
* `-m` (Image option): This option takes the name
  of the module as it is specified in [Forge API](https://forge.puppet.com/).
  In this example, we provide an arbitrary module name,
  since the provided Puppet script does not exist in Forge API.
* `-i` (Image option): This option indicates if we must install
  the Puppet module from Forge API before proceeding to the analysis.
  Available options are `no`, `latest`, and `<version-number>`.
  In this example, we provided `-i no`,
  because this Puppet script does not appear in Forge API as a separate
  module.
* `-s` (Image option): This flag indicates that we must run Puppet script
  through `FSMove`. Absence of this flag applies Puppet script without
  `FSMove`.

After the aforementioned command exits,
you can examine the results of the analysis
inside the `$(pwd)/out/` directory.
In particular,
the command produces the following six (6) files:
* `mysql-db.json`: Compiled catalog of Puppet module.
* `mysql-db.strace`: System call trace produced by `strace`.
* `mysql-db.size`: Size of system call trace (in bytes)
* `application.time`: Time spent to apply module.
* `mysql-db.times`: Time spent on analysis trace analysis
* `mysql-db.faults`: Faults detected by `FSMove`.


The contents of `mysql-db.faults` are similar to
```bash
Start executing manifest /home/fsmove/init.pp ...
Missing Ordering Relationships:
===============================
# Faults: 1
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
(defined at line 14 of the example Puppet script),
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
For more details see the first motivating example
described in our paper (Section 2).

### Running and analyzing a Real-world Puppet module

It's time to run and analyze a real-world Puppet module,
namely [alertlogic-al_agents](https://forge.puppet.com/alertlogic/al_agents),
through `FSMove`.
Again,
we will use our Docker image `fsmove`
to spawn a fresh Puppet environment.
Run the following command
```bash
 sudo docker run -ti --rm  --security-opt seccomp:unconfined -v "$(pwd)"/out:/home/fsmove/data fsmove -m alertlogic-al_agents -i 0.2.0 -s
```
Notice that this time,
we provided the option `-i 0.2.0`,
as we need to install the `alertlogic-al_agents` module
(version 0.2.0) in the system,
before proceeding to the analysis.
Also,
notice that this time
we did not mount any file into
`/home/fsmove/init.pp`,
because the script will create the entrypoint file
that uses `alertlogic-al_agents`,
after the installation of the corresponding module.

After the completion of the command above
(it takes 1-2 minutes),
we are now ready to examine the results of the analysis
stored inside the `out/` directory.
The contents of `out/alertlogic-al_agents.faults` file
are
```bash
Start executing manifest /home/fsmove/init.pp ...
Missing Ordering Relationships:
===============================
# Faults: 1
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
