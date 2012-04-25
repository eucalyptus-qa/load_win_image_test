#!/bin/sh

function whereis_eucalyptus {
     if [ $# -lt 1 ]; then
         part="CLC"
     else
         part=$1 
     fi
line=$(cat ../input/2b_tested.lst | grep "\[*\]" | grep $part)
     if echo $line | grep BZR > /dev/null; then
         echo "/opt/eucalyptus"
     elif echo $line | grep REPO > /dev/null; then
         echo "" 
     else
         echo "ERROR"
     fi
     return 0
}

function should_test_guest {
      if cat ../input/2b_tested.lst | grep "NC00" | grep RHEL > /dev/null; then
          if cat ../input/2b_tested.lst | grep "NC00" | grep "6." > /dev/null; then
               if cat ../input/2b_tested.lst | grep "windowsserver2003r2_ent_x86.kvm.img" > /dev/null; then
                    return 1; # dont test guest
               fi
          fi
      fi
      return 0;
}

function host_bitness {
     cat ../input/2b_tested.lst | grep NC00 | cut -f 4 
}

function guest_bitness {
     if cat ../input/2b_tested.lst | grep IMG_FILE | grep 86 > /dev/null; then
         echo "32"
     else
         echo "64"
     fi
}

function setup_euca2ools {
        dir=$(cat ../input/2b_tested.lst  | grep EUCA2OOLS_PATH | cut -f2 -d '=' | sed 's/[ \r]//g')
        if [ -z $dir ]; then
            echo "No Euca2ools path in MEMO"
            dir="../../load_win_image_test/stage01"
        else
	    dir="../../$dir"
        fi
        echo "EUCA2OOLS DIR: $dir"
        export PYTHONPATH=$dir/boto:$dir/euca2ools-main
        export PATH=$dir/euca2ools-main/bin:$PATH
        echo "EUCA2OOLS VERSION: $(euca-version)"
}

function whereis_keyfile {
      if [ $# -lt 1 ]; then
          echo "keyname is not given"
          return 1;
      fi
      keyname=$1
      dir=$(pwd)
      if echo $dir | grep "_No_" > /dev/null; then
         # find the number
         testno=${dir#*_No_}
         testno=${testno/\/*/}
         testno="_No_$testno"
         echo "../../windows_basic_test$testno/stage02/$keyname.priv"
      else
         echo "../../windows_basic_test/stage02/$keyname.priv"
      fi
      return 0
}

function get_networkmode {
    unset IFS
    mode=$(cat ../input/2b_tested.lst | grep NETWORK | cut -f2)
    echo $mode 
}

function write_imagesize {
     if [ $# -lt 1 ]; then
          echo "image size is not given"
          return 1;
      fi
      imgsize=$1
      dir=$(pwd)
      if echo $dir | grep "_No_" > /dev/null; then
         # find the number
         testno=${dir#*_No_}
         testno=${testno/\/*/}
         testno="_No_$testno"
         echo $imgsize > "../../windows_bundle_test$testno/etc/imgsize"
      else
         echo $imgsize > "../../windows_bundle_test/etc/imgsize"
      fi
      return 0

}


# $1 --> bucket name
# $2 --> image size
function wait_for_unbundle {
  if [ $# -lt 2 ]; then
        echo "not all parameter  is given"
        return 1
  fi

  ret=$(cat ../input/2b_tested.lst | grep 'WS')
  if [ -z "$ret" ]; then
           echo "Can't find walrus node"   
  fi
  IFS_OLD=$IFS
  unset IFS
  eucaroot=$(whereis_eucalyptus)
  walrusaddr=$(echo $ret | cut -f1 -d ' ')
  echo "Walrus' IP: $walrusaddr"
  if [ -z "$walrusaddr" ]; then
        echo "Walrus IP address is null; just waiting 30 min."
        sleep 1800 # 30 minutes
  else
        j=0
        timeout=45;  # wait for 45 minutes maximum
        while [ $j -lt $timeout ]; do
             filelist=$(ssh -o StrictHostKeyChecking=no root@$walrusaddr "ls -la $eucaroot/var/lib/eucalyptus/bukkits/$1");
             if echo $filelist | grep $2; then
                 echo "Image untar/unzip complete. now breaking out of the loop";
                 break;
             fi
             echo "Waiting for image registration to finish..."
             echo "Files: $filelist"
             sleep 60
             ((j++))
        done
   fi
   sleep 10
   IFS=$IFS_OLD
}

function run_at {
        if [ $# -lt 2 ]; then
                echo "run_at: not all parameter  is given"
                return 1
        fi
        host=$1
        cmd=$2
        echo "running '$cmd' at '$host'"
        if ssh -o StrictHostKeyChecking=no $host "$cmd"; then
                return 0;
        else
                echo "ssh execution failed"
                return 1;
        fi
} 

function describe_hypervisor {
	if cat ../input/2b_tested.lst | grep "NC00" | grep MAVERICK > /dev/null; then
       	      hypervisor="kvm";
	elif cat ../input/2b_tested.lst | grep "NC00" | grep LUCID > /dev/null; then
              hypervisor="kvm";
	elif cat ../input/2b_tested.lst | grep "NC00" | grep KARMIC > /dev/null; then
              hypervisor="kvm";
	elif  cat ../input/2b_tested.lst | grep "NC00" | grep CENTOS > /dev/null; then
            if cat ../input/2b_tested.lst | grep "NC00" | grep "6\.[0-9]*" > /dev/null; then
                hypervisor="kvm";
            else
                hypervisor="xen"; 
            fi
        elif  cat ../input/2b_tested.lst | grep "NC00" | grep RHEL > /dev/null; then
            if cat ../input/2b_tested.lst | grep "NC00" | grep "6\.[0-9]*"  > /dev/null; then
                hypervisor="kvm";
            else
                hypervisor="xen"; 
            fi
        elif  cat ../input/2b_tested.lst | grep "NC00" | grep DEBIAN > /dev/null; then
              hypervisor="xen";
	elif  cat ../input/2b_tested.lst | grep "NC00" | grep OPENSUSE > /dev/null; then
              hypervisor="xen";
	elif  cat ../input/2b_tested.lst | grep "NC00" | grep FEDORA > /dev/null; then
              hypervisor="xen";
	elif cat ../input/2b_tested.lst | grep "NC00" | grep VMWARE > /dev/null; then
              hypervisor="vmware";
	elif cat ../input/2b_tested.lst | grep "NC00" | grep WINDOWS > /dev/null; then
              hypervisor="hyperv";
	else
             echo "ERROR: Hypervisor is unknown"
             exit 1
 	fi
	echo "$hypervisor"
}
