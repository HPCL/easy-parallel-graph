#!/bin/bash
# A script to download the latest version of graphalytics, find out
# all of the dependencies, then download the desired platforms.
# Author: Sam Pollard, University of Oregon

# Most steps were taken from the README of the given repository

# CHANGE THESE TO BE CORRECT!
# Variables to set (put as command line arguments)
# For SamXu2
BASE_DIR="$HOME/uo/research/graphalytics"
HADOOP_HOME="$HOME/uo/research/graphalytics/hadoop-2.7.3"
# For Mac
#BASE_DIR=$HOME/Documents/uo/research/graphalytics
#HADOOP_HOME="$HOME/bin/hadoop"
# For Arya
#BASE_DIR="$HOME/graphalytics"
#HADOOP_HOME="$HOME/hadoop-2.7.3"

### Set up some variables and script options
# So ! doesn't expand in the shell
set +o histexpand
# So Ctrl-C works
trap "exit 1" INT
# So we can bail if something goes wrong
export TOP_PID=$$ 

osname=$(uname)
if [ "$JAVA_HOME" = "" -a "$osname" = "Linux" ]; then
	export JAVA_HOME=$(update-java-alternatives -l | awk '{print $3}')
elif [ -z "$JAVA_HOME" -a "$osname" = "Darwin" ]; then
	export JAVA_HOME=$(/usr/libexec/java_home)
elif [ -z $"JAVA_HOME" ]; then
	echo "Please set the environment variable JAVA_HOME. This is the directory where jdk is installed."
	kill -s TERM $TOP_PID
fi
if [ "$HADOOP_HOME" = "" -o "$BASE_DIR" = "" ]; then
	echo "You need to set HADOOP_HOME and BASE_DIR before this will work"
	exit 1
fi
if [ "$osname" = Darwin ]; then
	NUM_CORES=$(sysctl -n hw.ncpu)
	NUM_THREADS=$NUM_CORES
	MEM_KB=$(($(vm_stat | grep "Pages free:" | awk '{print $3}' | tr -d .) * $(vm_stat | head -n 1 | grep -E -o [0-9]+) / 1024 ))
	NUM_SOCKETS=1 # Is this always true?
	NUM_NODES=1
else
	NUM_CORES=$(grep -c ^processor /proc/cpuinfo)
	NUM_THREADS=$NUM_CORES # Intel already counts 2x for hyperthreaded cores
	MEM_KB=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
	#NUM_SOCKETS=$(grep -i "physical id" /proc/cpuinfo | sort -u | wc -l)
	NUM_NODES=1
fi
GA_DIR="$BASE_DIR/ldbc_graphalytics"
DATASET_DIR=$BASE_DIR/datasets


install_graphalytics()
{
	if [ ! $(find $BASE_DIR -type d -name ldbc_graphalytics) ]; then
		echo "Cloning and mvn-ing graphalytics into $GA_DIR... "
		cd "$BASE_DIR"
		git clone https://github.com/ldbc/ldbc_graphalytics.git
		cd ldbc_graphalytics
		mvn install
		cp -r config-template config
		echo "Changing graphs.root-directory in config to $DATASET_DIR"
		echo "$osname" | grep -q '.*BSD'
		if [ $? -eq 0 -o "$osname" = "Darwin" ]; then
			sed -i '' "s?graphs.root-directory.*?graphs.root-directory = $DATASET_DIR?" "$GA_DIR/config/graphs.properties"
		else
			sed -i "s?graphs.root-directory.*?graphs.root-directory = $DATASET_DIR?" "$GA_DIR/config/graphs.properties"
		fi
		cd ..
	else
		echo "I found an ldbc_graphalytics directory. I assume everything is built in there."
	fi
}

# Ensures all the correct dependencies are installed on the machine.
# If not, this will install them (if possible) and if not, provides a URL.
check_hadoop_dependencies()
{
	incomplete=false
	javac -version
	if [ $? -ne 0 ]; then
		echo "Please install jdk 1.6+. JDK 1.8 can be found at"
		echo 'http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html'
		echo 'On Debian-based systems, sudo apt-get install default-jdk works'
		incomplete=true
	fi

	mvn --version
	if [ $? -eq 127 ]; then # Command not found
		echo "Please install maven"
		incomplete=true
	else
		echo "I'm assuming you have maven version 3.0 or later."
	fi

	if [ $incomplete = true ]; then
		echo "Hadoop dependencies not satisfied."
		kill -s TERM $TOP_PID
	fi
}

# Install GraphX. This must be done before anything else which requires HDFS since it will start
# some hadoop daemons/services.
# Source: https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SingleCluster.html
# If you have hadoop installed, you must change HADOOP_HOME to where your
# distribution is located. (try whereis hadoop)
# If you have java, you must change JAVA_HOME environment variable
# to where your java directory is located. (try whereis java)
start_hadoop()
{
	echo "Checking if Hadoop is running..."
	$HADOOP_HOME/bin/hdfs dfsadmin -report
	if [ $? -ne 0 ]; then
		echo "Hadoop is not running."
#		read -n 1 -r -p 'Are you trying to start Hadoop in pseudo-distributed (single node)? [Y/n]'
#		if [[ $REPLY =~ ^[Yy]$ ]]; then
			# Stuff for installing hadoop. it's assumed you already have it installed.
			#HADOOP_URL='http://www-us.apache.org/dist/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz'
			#wget $HADOOP_URL
			#mkdir -p $HADOOP_HOME
			#tar xf $(basename $HADOOP_URL) -C $HADOOP_HOME
			#HADOOP_HOME=$(find . -maxdepth 1 -type d -name 'hadoop-*')
			#cd $HADOOP_HOME
		# Check if you can ssh into yourself
		ssh -oPreferredAuthentications=publickey localhost exit
		if [ $? -ne 0 ]; then
			echo "Problem executing `ssh localhost`. This may be one of several things:"
			echo -e "You must enable passwordless ssh into localhost:\n"
			echo "ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa"
			echo -e "\nAnd give it an empty password, then type\n"
			echo 'cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys'
			echo "chmod 0600 ~/.ssh/authorized_keys"
			echo -e"\nRemote login may be turned off in settings. You may also need to add"
			echo "PubkeyAuthentication = yes in /etc/ssh_config (the setting is off by default on Mac)"
			echo "You must also have an ssh client and an ssh server running on your machine."
			kill TERM $TOP_PID
		fi
		echo "Editing configuration for pseudo-distributed mode if none exists"
		# Like sed -i, but better. Only replace configs which are empty.
		# -0777 allows perl to slurp files whole. -i in place, -e for a one-liner, -p wraps a while loop across file
		perl -0777 -i.original -pe 's?<configuration>\s*</configuration>?<configuration>\n\t<property>\n\t\t<name>fs.defaultFS</name>\n\t\t<value>hdfs://localhost:9000</value>\n\t</property>\n</configuration>?' $HADOOP_HOME/etc/hadoop/core-site.xml
		perl -0777 -i.original -pe 's?<configuration>\s*</configuration>?<configuration>\n\t<property>\n\t\t<name>dfs.replication</name>\n\t\t<value>1</value>\n\t</property>\n</configuration>' $HADOOP_HOME/etc/hadoop/hdfs-site.xml

		echo "Editing hadoop-env.sh to ensure JAVA_HOME is set. It is recommended you export JAVA_HOME in the global /etc/profile"
		perl -0777 -i.original -pe "s?export JAVA_HOME.*\n?export JAVA_HOME=$JAVA_HOME\n?" $HADOOP_HOME/etc/hadoop/hadoop-env.sh
		### Start Hadoop
		# Format the filesystem		
		$HADOOP_HOME/bin/hdfs namenode -format
		#$HADOOP_HOME/bin/hdfs secondarynamenode -format
		# Start name node daemon and data node daemon
		$HADOOP_HOME/sbin/start-dfs.sh
		echo "You can check the status of your file system at http://localhost:50070/"
	fi
	$HADOOP_HOME/bin/hdfs dfs -mkdir /user
	$HADOOP_HOME/bin/hdfs dfs -mkdir /user/$USER
	$HADOOP_HOME/bin/hdfs dfs -mkdir /user/$USER/graphalytics
}

# Starts the yarn tasks. Assumes the configuration files are set up
start_yarn()
{
	# Check if the ResourceManager and NodeManager daemons are running
	if [ $(ps axu | grep yarn | wc -l) -lt 3 ]; then
		$HADOOP_HOME/sbin/start-yarn.sh
	else
		echo "YARN is running. You can check its status at http://localhost:8088/"
	fi
	
	if [ $? -ne 0 ]; then
		perl -0777 -i.original -pe 's?<configuration>\s*</configuration>?<configuration>\n\t<property>\n\t\t<name>mapreduce.framework.name</name>\n\t\t<value>yarn</value>\n\t</property>\n</configuration>?' "$HADOOP_HOME/etc/hadoop/mapred-site.xml"
		perl -0777 -i.original -pe 's?<configuration>\s*</configuration>?<configuration>\n\t<property>\n\t\t<name>yarn.nodemanager.aux-services</name>\n\t\t<value>mapreduce_shuffle</value>\n\t</property>\n</configuration>?' "$HADOOP_HOME/etc/hadoop/yarn-site.xml"
		exit 1
	fi
}

install_GraphX()
{
	# Assumes HDFS and YARN are running.
	echo "Installing GraphX..."
	OLDWD=$(pwd)
	cd "$BASE_DIR"
	if [ ! $(find "$BASE_DIR" -maxdepth 1 -type d -name graphalytics-platforms-graphx) ]; then
		#git clone https://github.com/tudelft-atlarge/graphalytics-platforms-graphx.git
		# XXX: Temporary fix until it's merged into main branch
		git clone https://github.com/sampollard/graphalytics-platforms-graphx
	fi
	GRAPHX_DIR="$BASE_DIR/graphalytics-platforms-graphx"
	cd "$GRAPHX_DIR"
	mvn install

	PKGNAME=$(basename $(find $GRAPHX_DIR -maxdepth 1 -name *.tar.gz))
	VERSION=$(echo $PKGNAME | awk -F '-' '{print $4}')
	GA_VERSION=$(echo $PKGNAME | awk -F '-' '{print $2}')
	platform=$(echo $PKGNAME | awk -F '-' '{print $3}')
	PKGNAME=$(basename $(find $GRAPHX_DIR -maxdepth 1 -name *.tar.gz))
	tar -xf "$PKGNAME"

	PKGDIR="$GRAPHX_DIR/graphalytics-$GA_VERSION-$platform-$VERSION"

	# Configure GraphX
	cp -r "$PKGDIR/config-template" "$PKGDIR/config"
	echo "graphx.job.num-executors = $NUM_NODES" > "$PKGDIR/config/graphx.properties"
	echo "graphx.job.executor-memory = ${MEM_KB}k" >> "$PKGDIR/config/graphx.properties"
	echo "graphx.job.executor-cores = $NUM_CORES" >> "$PKGDIR/config/graphx.properties"
	echo "hadoop.home= $HADOOP_HOME" >> $PKGDIR/config/graphx.properties
	# Don't need to specify filesystem authority, but it is the default: localhost:9000
	echo "$osname" | grep -q '.*BSD'
	if [ $? -eq 0 -o "$osname" = "Darwin" ]; then
		sed -i '' 's/readlink -f/stat -f/' "$PKGDIR/run-benchmark.sh"
		# Will ONLY work one level of symlink. For a full recursive solution, see
		# stackoverflow.com/questions/7665/how-to-resolve-symbolic-links-in-a-shell-script
	fi
	$HADOOP_HOME/bin/hadoop fs -copyFromLocal $PKGDIR "hdfs:///user/$USER/graphalytics/$platform"

	cd "$OLDWD"
}

install_OpenG()
{
	if [ "$osname" != "Linux" ]; then
		echo "GraphBIG only works on Linux."
		exit 1
	fi
	cd "$BASE_DIR"
	GRAPHBIG_DIR="$BASE_DIR/graphBIG"
	export OPENG_HOME="$GRAPHBIG_DIR"
	if [ "$osname" != "Linux" ]; then
		GRAPHBIG_OPTS="PFM=0"
	else
		GRAPHBIG_OPTS=""
	fi
	if [ ! $(find . -type d -name graphBIG) ]; then
		echo "Downloading and building the GraphBIG repository"
		git clone 'https://github.com/graphbig/graphBIG.git'
		cd "$GRAPHBIG_DIR"
		git checkout graphalytics
		make clean
		make "$GRAPHBIG_OPTS" all
	fi
	cd "$BASE_DIR"

	OPENG_DIR=$BASE_DIR/graphalytics-platforms-openg
	if [ ! $(find . -type d -name graphalytics-platforms-openg) ]; then
		# Get the package configured and built
		git clone 'https://github.com/tudelft-atlarge/graphalytics-platforms-openg.git'
	fi
	cd "$OPENG_DIR" # You have to be in this dir for it to work
	mvn package
	PKGNAME=$(basename $(find $OPENG_DIR -maxdepth 1 -name *.tar.gz))
	tar -xf "$PKGNAME"
	PKGNAME=$(basename $(find $OPENG_DIR -maxdepth 1 -name *.tar.gz))
	VERSION=$(echo $PKGNAME | awk -F '-' '{print $4}')
	GA_VERSION=$(echo $PKGNAME | awk -F '-' '{print $2}')
	platform=$(echo $PKGNAME | awk -F '-' '{print $3}')

	PKGDIR="$OPENG_DIR/graphalytics-$GA_VERSION-$platform-$VERSION"
	# Configure OpenG
	CONFIG=$(printf "openg.home = $GRAPHBIG_DIR\nopeng.intermediate-dir = $GRAPHBIG_DIR/intermediate\nopeng.output-dir = $GRAPHBIG_DIR/output\nopeng.num-worker-threads=$NUM_THREADS")
	cp -r "$PKGDIR/config-template" "$PKGDIR/config"
	echo "$CONFIG" > $PKGDIR/config/$platform.properties
	perl -0777 -i.original -pe "s?graphs.root-directory.*?graphs.root-directory = $DATASET_DIR?" "$PKGDIR/config/graphs.properties"

}

# Downloads em all
download_datasets()
{
	# The full dataset is at http://atlarge.ewi.tudelft.nl/graphalytics/zip/dota-league.zip for example.
	wget -r -l 1 --no-clobber http://atlarge.ewi.tudelft.nl/graphalytics/data/ $DATASET_DIR
	# Get the reference solutions
	wget -r -l 1 --no-clobber http://atlarge.ewi.tudelft.nl/graphalytics/ref/ $DATASET_DIR
}

# Runs the benchmark $platform
# Requirements: $platform, $PKGDIR be defined.
run_benchmark()
{
	cd "$PKGDIR" # Very important that you're in the directory you un-tar'd
	. run-benchmark.sh # calls prepare-benchmark.sh
}
# For each platform repository package up an executable

### MAIN ###
### Make sure correct packages are installed
install_graphalytics
check_hadoop_dependencies
start_hadoop
start_yarn
#download_datasets

### Run the OpenG benchmark
install_OpenG
run_benchmark

### Run the GraphX benchmark
#install_GraphX
#run_benchmark
