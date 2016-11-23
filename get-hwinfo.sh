#!/bin/bash
# Gets hardware data and prints to standard output.
# Note: This utility will get better data if run as superuser.

OSNAME=$(uname)
dlm="\t"

# Get the data
if [ "$OSNAME" = Darwin ]; then
	CPU_SOCKETS=1 # This appears to be true on all Mac models so far.
	CPU_CORES=$(sysctl -n hw.ncpu) # The number of virtual cores (2x for hyperthreading is counted)
	#CHANGE TO RAM_SIZE: MEM_KB=$(($(vm_stat | grep "Pages free:" | awk '{print $3}' | tr -d .) * $(vm_stat | head -n 1 | grep -E -o [0-9]+) / 1024 ))
else
	CPU_MODEL=$(lscpu | grep "Model name" | awk -F ":" '{print $2}' | sed 's/^[[:space:]]*//')
	CPU_SOCKETS=$(grep -i "physical id" /proc/cpuinfo | sort -u | wc -l)
	CPU_CORES=$(grep -c ^processor /proc/cpuinfo) # The number of virtual cores are counted (2x for hyperthreading)
	CPU_CLOCK=$(printf "%.0f%s" $(lscpu | grep "CPU max MHz" | awk -F ":" '{print $2}' | sed 's/^\s*//') "MHz")
	RAM_SIZE=$(cat /proc/meminfo | grep MemTotal | awk '{print $2 / 1024 / 1024 "Gib"}')
fi

# Get data that requires superuser.
if [ -f "lshw.txt" ]; then
	RAM_FREQ=$(grep -E -m 1 'clock: [0-9]+.*\(' lshw.txt | awk '{print $2}')
	GPU_MODEL=$(grep -E -A 11 '\*-display' lshw.txt | grep product | sed 's/^\s*product:\s//')
else
	echo -e "To get more in-depth hardware info run the command\n"
	echo -e "sudo lshw > lshw.txt\n"
fi

# Prints a record. Requires 2 arguments: The string and the value associated with that.
print_record()
{
	if [ "$#" -lt 2 ]; then
		exit # Do nothing since the value is empty
	fi
	printf "$1${dlm}$2\n"
}

# Print the data
print_record "CPU Model" "$CPU_MODEL"
print_record "CPU Sockets" "$CPU_SOCKETS"
print_record "CPU Cores" "$CPU_CORES"
print_record "CPU Clock" "$CPU_CLOCK"
# TODO: May want to add a field for flags. Specifically, what level of SIMD there is.
# i.e. avx512 > avx2 > avx > sse2 > sse
#printf "CPU SIMD${dlm}$CPU_SIMD\n"
print_record "RAM Size" "$RAM_SIZE"
print_record "RAM Freq" "$RAM_FREQ"
print_record "GPU Model" "$GPU_MODEL"

