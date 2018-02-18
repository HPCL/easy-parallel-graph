#!/usr/bin/env python
import sys,os,glob
import numpy as np
import pandas as pd

phases = {
    "Starting creation of rooted tree" : "MST-Rooted",
    "Starting Classify and Insert" : "MST-Insert",
    "Starting process_deletions" : "MST-Delete",
    "INFO: CommandLine" : "Galois-All",
    "STAT,(NULL),Time" : "DONE",
    "Total Time for Updating" : "DONE",
}

sleep_power={1:35.59980, 2:32.50874, 4:39.00752, 8:27.53429, 16:29.59654, 24:26.78392,
    32:28.23629, 40:29.28156, 48:29.53099, 56:27.61415, 64:25.24939, 72:29.56577}
sleep_energy={1:356.00497, 2:325.09772, 4:390.13837, 8:275.48913, 16:296.30119, 24:268.22497,
    32:283.00666, 40:293.51369, 48:296.04856, 56:276.91622, 64:253.14684, 72:296.29419}

def usage():
    print("Usage: power_summarize.py <directory with log files>")

networks = {}

class Network:
    def __init__(self,paramstr):
        global phases,cpus
        self.id = paramstr
        self.time = {}
        self.power = {}
        self.energy = {}
        for pkg in [0,1]:
            self.time[pkg] = {}
            self.power[pkg] = {}
            self.energy[pkg] = {}
            for p in phases.values():
                if p == "DONE": continue
                self.time[pkg][p] = []
                self.energy[pkg][p] = []
                self.power[pkg][p] = []

    def extendData(self,phase,t,e,p):
        if phase == "DONE": return
        #print("Extending",str(t),str(e),str(p))
        for pkg in [0,1]:
            self.time[pkg][phase].append(t[pkg])
            self.energy[pkg][phase].append(e[pkg])
            self.power[pkg][phase].append(p[pkg])

    def print(self):
        print(self.id)
        print(self.time)
        print(self.energy)
        print(self.power)
    
    def __repr__(self):
        buf = self.id + ':'
        buf += "\nTime:" + str(self.time)
        buf += "\nEnergy:" + str(self.energy)
        buf += "\Power:" + str(self.power)
        return buf


def processLog(logpath):
    global networks
    # For example, output-8epv/mst-248_ER_100i_1000000_16t.log
    log = os.path.basename(logpath).split('.')[0]
    ind = log.find('-')
    which = log[:ind]
    paramstr = log[ind+1:]
    if paramstr not in networks.keys():
        networks[paramstr] = Network(paramstr)

    params = paramstr.split('_')
    # Examples of (which, params):
    # mst ['248', 'G', '100i', '1000000', '64t']
    # galois ['248', 'ER', '100i', '1000000', '4t']
    phase = None; time = [None]*2; energy=[None]*2; power=[None]*2
    lines = open(logpath,'r').readlines()
    for line in lines:
        line = line.strip()
        if line.startswith("Found"): continue
            #if line.startswith("Time Taken for Initializing") or
            #line.startswith("Galois Benchmark Suite"): phase = None
        s = line.split()
        
        for p in phases.keys():
            #print(p,line)
            if line.startswith(p):
                if phase: networks[paramstr].extendData(phase,time,energy,power)
                phase = phases[p]  # new phase
                time = [None]*2; energy=[None]*2; power=[None]*2
                #print("New phase: ",phase)
                break


        if phase == "DONE": phase = None
        if not phase: continue
        if line.find("rapl:::PACKAGE_ENERGY:PACKAGE") < 0: continue
        # See more complete example RAPL output at bottom of file
        # 2.9492 s 195.8815 (* Total Energy for rapl:::PACKAGE_ENERGY:PACKAGE0 *)

        # Get triplets: time, total energy, average power
        if phase and line.find("rapl:::PACKAGE_ENERGY:PACKAGE") > 0:
            #print(logpath,line)
            pkg = int(s[-2][-1])
            if not time[pkg]: time[pkg]=float(s[0])
            if line.find("Total Energy for rapl:::PACKAGE_ENERGY:PACKAGE")>0:
                energy[pkg]=float(s[2])
            if line.find("Average Power for rapl:::PACKAGE_ENERGY:PACKAGE")>0:
                power[pkg]=float(s[2])


def processLogs():
    global phases
    if len(sys.argv) < 2:
        usage()
        sys.exit(1)
    logdir = sys.argv[1]
    if not os.path.exists(logdir):
        print("Error: invalid path %s" % logdir)
        usage()
        sys.exit(1)

    logfiles = glob.glob(logdir+"/*.log")
    for logpath in logfiles:
        processLog(logpath)

def main():
    processLogs()
    for n in networks.values():
        n.print()
        pass


if __name__ == "__main__":
    main()
    sys.exit(0)


# Just the relevant portion of the output
#2.9492 s 195.8815 (* Total Energy for rapl:::PACKAGE_ENERGY:PACKAGE0 *)
#2.9492 s 66.4193 (* Average Power for rapl:::PACKAGE_ENERGY:PACKAGE0 *)
#2.9492 s 69.8333 (* Total Energy for rapl:::PACKAGE_ENERGY:PACKAGE1 *)
#2.9492 s 23.6790 (* Average Power for rapl:::PACKAGE_ENERGY:PACKAGE1 *)
#2.9492 s 16.8307 (* Average Power for rapl:::DRAM_ENERGY:PACKAGE0 *)
#2.9492 s 8.7852 (* Average Power for rapl:::DRAM_ENERGY:PACKAGE1 *)
#2.9492 s 0.0000 (* Average Power for rapl:::PP0_ENERGY:PACKAGE0 *)
#2.9492 s 0.0000 (* Average Power for rapl:::PP0_ENERGY:PACKAGE1 *)




