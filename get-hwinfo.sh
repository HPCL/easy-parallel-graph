#!/bin/bash
# Gets hardware data and prints to standard output.
# Note: This utility will get better data if the user can run commands as root.

OSNAME=$(uname)
dlm="\t"

# Get the data
if [ "$OSNAME" = Darwin ]; then
	CPU_MODEL=$(sysctl -n machdep.cpu.brand_string)
	CPU_SOCKETS=1 # This appears to be true on all Mac models.
	CPU_CORES=$(sysctl -n hw.ncpu) # The number of virtual cores (2x for hyperthreading is counted)
	RAM_SIZE=$(sysctl -n hw.memsize | awk '{print $0 / 1024 / 1024 / 1024 "Gib"}')
	CPU_CLOCK=$(printf "%.0f %s" $(echo $(sysctl -n hw.cpufrequency_max) "/ 1000000" | bc) "MHz")
	echo "Running system_profiler and saving to /tmp/profile.txt. This will be deleted afterwards."
	system_profiler > /tmp/profile.txt
	RAM_FREQ=$(cat /tmp/profile.txt | grep -A 16 "Memory:$" | grep "Speed" | awk -F ":" '{print $2}' | sed 's/^[[:space:]]*//')
	GPU_MODEL=$(cat /tmp/profile.txt | grep -A 11 "Graphics/Displays" | grep "Chipset" | awk -F ":" '{print $2}' | sed 's/^[[:space:]]*//')
	rm /tmp/profile.txt
else
	CPU_MODEL=$(lscpu | grep "Model name" | awk -F ":" '{print $2}' | sed 's/^[[:space:]]*//')
	CPU_SOCKETS=$(grep -i "physical id" /proc/cpuinfo | sort -u | wc -l)
	CPU_CORES=$(grep -c ^processor /proc/cpuinfo) # The number of virtual cores are counted (2x for hyperthreading)
	RAM_SIZE=$(cat /proc/meminfo | grep MemTotal | awk '{print $2 / 1024 / 1024 "Gib"}')
	CPU_CLOCK=$(printf "%.0f %s" $(lscpu | grep "CPU max MHz" | awk -F ":" '{print $2}' | sed 's/^\s*//') "MHz")
	CPU_SIMD=$(sysctl -n machdep.cpu.features)
fi

# Get data that requires superuser.
if [ -f "lshw.txt" ]; then
	RAM_FREQ=$(grep -E -m 1 'clock: [0-9]+.*\(' lshw.txt | awk '{print $2}')
	GPU_MODEL=$(grep -E -A 11 '\*-display' lshw.txt | grep product | sed 's/^\s*product:\s//' | tr "\n" " ")
elif [ "$OSNAME" = Linux ]; then
	echo -e "To get more in-depth hardware info run the command\n"
	echo -e "sudo lshw > lshw.txt\n"
fi

# Prints a record. Requires 2 arguments: The string and the value associated with that.
print_record()
{
	if [ ! -z "$2" ]; then
		printf "$1${dlm}$2\n"
	fi
	# Otherwise print nothing since there is no value.
}

# Print the data
print_record "CPU Model" "$CPU_MODEL"
print_record "CPU Sockets" "$CPU_SOCKETS"
print_record "CPU Cores" "$CPU_CORES"
print_record "CPU Clock" "$CPU_CLOCK"
# TODO: May want to add a field for flags. Specifically, what level of SIMD there is.
# i.e. avx512 > avx2 > avx > sse2 > sse
# Another useful detail may be the version of CUDA supported.
print_record "RAM Size" "$RAM_SIZE"
print_record "RAM Freq" "$RAM_FREQ"
print_record "GPU Model" "$GPU_MODEL"

