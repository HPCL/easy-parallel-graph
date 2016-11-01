#!/bin/bash
# A script to download the latest version of graphalytics, find out
# all of the dependencies, then download the desired platforms.
# Author: Sam Pollard, University of Oregon

# Most steps were taken from the README of the given repository

# CHANGE THESE TO BE CORRECT!
# Variables to set (put as command line arguments)
#BASE_DIR=""
#export JAVA_HOME=""
#HADOOP_HOME=""
# For Mac
#BASE_DIR=$HOME/Documents/uo/research/graphalytics
#HADOOP_HOME="$HOME/bin/hadoop"
# For Arya
BASE_DIR="$HOME/graphalytics"
HADOOP_HOME="$HOME/hadoop-2.7.3"

### Set up some variables and script options
# So ! doesn't expand in the shell
set +o histexpand
# So Ctrl-C works
trap "exit 1" INT

init_vars()
{
	osname=$(uname)
	if [ "$JAVA_HOME" = "" -a "$osname" = "Linux" ]; then
		export JAVA_HOME=$(update-java-alternatives -l | awk '{print $3}')
	elif [ -z "$JAVA_HOME" -a "$osname" = "Darwin" ]; then
		export JAVA_HOME=$(/usr/libexec/java_home)
	elif [ -z $"JAVA_HOME" ]; then
		echo "Please set the environment variable JAVA_HOME. This is the directory where jdk is installed."
		javac -version
		if [ $? -ne 0 ]; then
			echo "Please install jdk 1.6+. JDK 1.8 can be found at"
			echo 'http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html'
			exit 1
		fi
		exit 1
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
}

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
	if [ "$osname" = Darwin ]; then
		installcmd="brew install"
	elif [ "$osname" = Linux ]; then
		installcmd="sudo apt-get install"
	else # Not supported---the user has to figure it out.
		installcmd="echo Please install"
	fi
	mvn --version
	if [ $? -eq 127 ]; then # Command not found
		echo "Installing maven"
		$installcmd maven
		if [ "$installcmd" = "echo Please install" ]; then
			incomplete=true
		fi
	else
		echo "I'm assuming you have maven version 3.0 or later."
	fi

	if [ $incomplete = true ]; then
		echo "Hadoop dependencies not satisfied."
		exit 1
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
		# TODO: Have these input
		#export JAVA_HOME="/usr/share/java"
		#HADOOP_HOME="/usr/local/hadoop"
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
			echo "You must enable passwordless ssh into localhost:"
			echo "ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa"
			echo "And give it an empty password, then type"
			echo "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"
			echo "chmod 0600 ~/.ssh/authorized_keys"
			echo "Remote login may be turned off in settings. You may also need to add"
			echo "PubkeyAuthentication = yes in /etc/ssh_config"
			exit 1
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
		$HADOOP_HOME/bin/hdfs dfs -mkdir /user
		$HADOOP_HOME/bin/hdfs dfs -mkdir /user/$USER
		$HADOOP_HOME/bin/hdfs dfs -mkdir /user/$USER/graphalytics
	fi
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
		echo "You must edit $HADOOP_HOME/etc/hadoop/mapred-site.xml"
		printf '<configuration>
     <property>
         <name>mapreduce.framework.name</name>
         <value>yarn</value>
     </property>
 </configuration>'

 		echo "And $HADOOP_HOME/etc/hadoop/yarn-site.xml"
		printf '<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>'
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
		#git clone 'https://github.com/tudelft-atlarge/graphalytics-platforms-graphx.git'
		# Temporarily until they merge my repo
		git clone 'https://github.com/sampollard/graphalytics-platforms-graphx'
	fi
	# XXX: Temporary fix until it's merged into main branch
	# Source: http://www.daodecode.com/blog/2014/10/27/scala-maven-plugin-and-multiple-versions-of-scala-libraries-detected/
	# Add <scala.binary.version>2.10</scala.binary.version>
	# to
	# graphalytics-platforms-graphx-granula/pom.xml
	# graphalytics-platforms-graphx-platform/pom.xml
	# graphalytics-platforms-graphx-std/pom.xml
	# And then add <scalaCompatVersion>${scala.binary.version}</scalaCompatVersion>
	# to
	# graphalytics-platforms-graphx-platform/pom.xml
	# right after the <scalaVersion> tag.
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
	$HADOOP_HOME/bin/hadoop fs -copyFromLocal $PKGDIR hdfs:///user/spollard/graphalytics/$platform

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
	if [ ! $(find . -type d -name graphBIG) ]; then
		echo "Downloading and building the GraphBIG repository"
		git clone 'https://github.com/graphbig/graphBIG.git'
		cd "$GRAPHBIG_DIR"
		git checkout graphalytics
		make clean all
	fi
	cd "$BASE_DIR"

	OPENG_DIR=$BASE_DIR/graphalytics-platforms-openg
	if [ ! $(find . -type d -name graphalytics-platforms-openg) ]; then
		# Get the package configured and built
		git clone 'https://github.com/tudelft-atlarge/graphalytics-platforms-openg.git'	
		cd "$OPENG_DIR" # You have to be in this dir for it to work
		mvn install
		PKGNAME=$(basename $(find $OPENG_DIR -maxdepth 1 -name *.tar.gz))
		tar -xf "$PKGNAME"
	fi
	cd "$OPENG_DIR"
	mvn install
	PKGNAME=$(basename $(find $OPENG_DIR -maxdepth 1 -name *.tar.gz))
	VERSION=$(echo $PKGNAME | awk -F '-' '{print $4}')
	GA_VERSION=$(echo $PKGNAME | awk -F '-' '{print $2}')
	platform=$(echo $PKGNAME | awk -F '-' '{print $3}')

	PKGDIR="$OPENG_DIR/graphalytics-$GA_VERSION-$platform-$VERSION"
	CONFIG=$(printf "openg.home = $GRAPHBIG_DIR\nopeng.intermediate-dir = $GRAPHBIG_DIR/intermediate\nopeng.output-dir = $GRAPHBIG_DIR/output\nopeng.num-worker-threads=$NUM_THREADS")
	echo "$CONFIG" > $PKGDIR/config/$platform.properties

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
init_vars
install_graphalytics
check_hadoop_dependencies
start_hadoop
start_yarn
#download_datasets

### Run the OpenG benchmark
install_OpenG
#run_benchmark

### Run the GraphX benchmark
install_GraphX
#run_benchmark
