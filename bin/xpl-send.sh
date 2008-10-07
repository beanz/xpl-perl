#!/bin/sh

addr=$1
shift

type='xpl-cmnd'
case "$1" in
  xpl-cmnd|xpl-stat|xpl-trig)
    type=$1
    shift
    ;;
esac

target='target=*'
case "$1" in
  target=*)
    target=$1
    shift
    ;;
esac

class='osd.basic'
case "$1" in
  *.*)
    class=$1
    shift
    ;;
esac

body=""
while read x ;do
  body="$body$x
"
done

echo "$type
{
hop=1
source=bnz-nc."`uname -n`"
$target
}
$class
{
$body}" | nc -q0 -b -u $addr 3865
