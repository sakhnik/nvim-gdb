#!/bin/bash

function Bar() {
    echo $(( $1 * 2 ))
}

function Foo() {
    if [[ $1 -eq 0 ]]; then
        echo 0
    else
        b=$(Bar $(($1 - 1)))
        echo $(( $1 + b ))
    fi
}

function Main() {
    for i in $(seq 1 5); do
        Foo "$i"
    done
}

Main
