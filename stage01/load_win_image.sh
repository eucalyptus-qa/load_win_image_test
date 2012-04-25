#!/bin/bash

# ../share/windows_images/currentimg
function download_and_setup_euca2ools {
        dir=$(cat ../input/2b_tested.lst  | grep EUCA2OOLS_PATH | cut -f2 -d '=' | sed 's/[ \r]//g') 
        if [ -z $dir ] || ! ls ../../$dir/euca2ools-main > /dev/null ; then
            echo "Downloading euca2ools"
	    . ./download_euca2ools.sh
	    if [ ! $? -eq 0 ]; then
	   	echo "euca2ools installation failed"
   		exit 1
	    fi
	    export PYTHONPATH="$(pwd)/boto:$(pwd)/euca2ools-main"
	    export PATH="$(pwd)/euca2ools-main/bin:$PATH"
        else
            dir="../../$dir"
            echo "EUCA2OOLS DIR: $dir"
            export PYTHONPATH=$dir/boto:$dir/euca2ools-main
            export PATH=$dir/euca2ools-main/bin:$PATH
        fi
	echo "EUCA2OOLS VERSION: $(euca-version)"
}

download_and_setup_euca2ools;
source ../lib/winqa_util.sh


hostbit=$(host_bitness)
guestbit=$(guest_bitness)
if [ $guestbit -eq "64" ] && [ $hostbit -eq "32" ]; then
    echo "Running 64 bit guest on 32 bit host"
    sleep 10
    exit 0
fi

hypervisor=$(describe_hypervisor)

ret=$(cat ../input/2b_tested.lst | grep 'CLC')
if [ -z "$ret" ]; then
      echo "Can't find CLC node"   
      exit -1
fi
IFS_OLD=$IFS
unset IFS
clcaddr=$(echo $ret | cut -f1 -d ' ')
echo "CLC's IP: $clcaddr"
if [ -z "$clcaddr" ]; then
      echo "CLC IP address is null"
      exit -1
fi

imgurl="http://dmirror/windows_images"
IFS=$'\n'
num_imgs=0
for img in $(cat ../input/2b_tested.lst | grep IMG_FILE | cut -f2 -d '=' | sed 's/[ \r]//g'); do imgs[((num_imgs++))]="$imgurl/$img"; done

for imgurl in "${imgs[@]}"; do
        echo "Image: $img"
	if euca-describe-images | grep "$img"; then 
		echo "$img already registered"	
		continue
	fi
	# download the image file to CLC
	echo "Downloading image file($imgurl) to CLC"
	ssh -o StrictHostKeyChecking=no root@$clcaddr "wget $imgurl -O  /disk1/storage/$img" > /dev/null 2>&1
	if !(ssh -o StrictHostKeyChecking=no root@$clcaddr "ls -la /disk1/storage/$img"); then
		echo "couldn't find the image file in the CLC";
		exit 1;
	fi
	echo "Downloading done"	
	# check image size
	imgsize=$(ssh -o StrictHostKeyChecking=no root@$clcaddr "ls -la /disk1/storage/$img" | cut -f5 -d ' ')
	if [ -z $imgsize ]; then
		echo "failed to determine image size";
		exit 1;
	fi
	echo "Image's size: $imgsize"
        write_imagesize $imgsize

	echo "Running euca-bundle-image"	
	# euca-bundle-image
	ret=$(ssh -o StrictHostKeyChecking=no root@$clcaddr "source /root/eucarc; mkdir /disk1/storage/bundle; euca-bundle-image -i /disk1/storage/$img -d /disk1/storage/bundle")

	if !(echo $ret | grep 'Generating manifest'); then
		echo "ERROR: Euca-bundle-image has failed"
		exit 1
	fi
	manifest="/disk1/storage/bundle/$img.manifest.xml"	
	if !(ssh -o StrictHostKeyChecking=no root@$clcaddr "ls -la $manifest"); then
		echo "ERROR: euca-bundle-image has failed; no manifest found";	
		exit 1
	fi

	echo "Bundle image complete; now running euca-upload-bundle"
	bucket="win$RANDOM"
        ret=$(ssh -o StrictHostKeyChecking=no root@$clcaddr "source /root/eucarc; euca-upload-bundle -b $bucket -m $manifest")

	if !(echo $ret | grep 'Uploaded image'); then
		echo "ERROR: Euca-upload-bundle has failed"
		echo $ret
		exit 1
	fi
	
	manifest=${ret/*Uploaded image as /}
	echo "Manfest at Walrus: $manifest"
	if [ -z "$manifest" ]; then
		echo "ERROR: Uploaded image path is null"
		exit 1
	fi
	echo "Upload bundle completes: $manifest"

	sleep 10
	ret=$(euca-register "$manifest")
	if !(echo $ret | grep 'IMAGE'); then
		echo "ERROR: euca-register failed"
		echo $ret
		exit 1
	fi
	echo "Image $img registered"

	if !(ssh -o StrictHostKeyChecking=no root@$clcaddr "rm -f /disk1/storage/$img"); then
            echo "Failed to delete $img from CLC"
        fi
 	if !(ssh -o StrictHostKeyChecking=no root@$clcaddr "rm -fr /disk1/storage/bundle"); then
            echo "Failed to delete temporary bundle directory from CLC"
        fi

      
	echo "Now waiting for CLC to unbundle registered image" 
        sleep 30	
        wait_for_unbundle $bucket $imgsize;
done
echo "Image registration complete"
exit 0

