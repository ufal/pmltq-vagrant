# Vagrant project for PML-TQ

This project creates a virtual machine with PML-TQ installation. The installation is using old `CGI` interface and is ideal for simple installations. Setup is based on [lindat-kontext-vagrant](https://github.com/ufal/lindat-kontext-vagrant).


## How to install

Prerequisites: [Vagrant](https://www.vagrantup.com/), [virtualbox](https://www.virtualbox.org/).

1. Clone this project
    ```
    git clone https://github.com/ufal/pmltq-vagrant
    ```

1. Create the VM by executing the following command from pmltq-vagrant directory 
    ```
    vagrant up
    ```

1. Go to [http://localhost:9999/](http://localhost:9999/) to see a front page with running treebanks

1. (optional) Login to the VM
    ```
    vagrant ssh
    ```
 