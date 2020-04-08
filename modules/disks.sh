function clear_partition() {
	dd if=/dev/urandom of=$1 bs=1M count=100
}

function make_partition() {
	local freespace=$(free_disk_space $1) 
    parted -s "$1" unit s mkpart primary "$2" "$3"
}

function free_disk_space() {
	parted -s $1 unit s print free | grep 'Free Space' | tail -n 1 | awk '{ print $3 }' | sed -e 's/s$//g'
}