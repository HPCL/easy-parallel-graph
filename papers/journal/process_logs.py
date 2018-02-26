#!/usr/bin/env python
import sys,os,glob
import numpy as np
import pandas as pd
import pprint

phases = {
    "Starting creation of rooted tree" : "MST-Rooted",
    "Starting Classify and Insert" : "MST-Insert",
    "Starting process_deletions" : "MST-Delete",
    "INFO: CommandLine" : "Galois-All",
    "Command being timed:" : "Total memory",
    "Exit status: 0" : "DONE"
}

sleep_power={1:35.59980, 2:32.50874, 4:39.00752, 8:27.53429, 16:29.59654, 24:26.78392,
    32:28.23629, 40:29.28156, 48:29.53099, 56:27.61415, 64:25.24939, 72:29.56577}
baseline_power = min(sleep_power.values())
sleep_energy={1:356.00497, 2:325.09772, 4:390.13837, 8:275.48913, 16:296.30119, 24:268.22497,
    32:283.00666, 40:293.51369, 48:296.04856, 56:276.91622, 64:253.14684, 72:296.29419}

alldata = {}

def usage():
    print("Usage: power_summarize.py <directory with log files>")

class Experiment:
    def __init__(self,which,name,num=0):
        global phases
        self.which = which
        self.name = name
        self.num = num
        self.time = {}
        self.power = {}
        self.energy = {}
        self.memory = {}
        for p in phases.values():
            if p in ["DONE","Total memory"]: continue
            self.time[p] = []
            self.energy[p] = []
            self.power[p] = []
    
    def set(self,num,which,phase,t,e,p,m):
        if phase == "DONE": return
        self.num = num
        if phase == "Total memory":
            self.memory[which + '-' + phase] = m
        else:
            #print("Extending",str(t),str(e),str(p))
            self.time[phase]=t  # tuple with values for each CPU
            self.energy[phase]=e # tuple with values for each CPU
            self.power[phase]=p # tuple with values for each CPU

    def __repr__(self):
        buf = "Experiment %d;%s" % (self.num,self.name)
        buf += "\n%s;Time(s):" % self.name + str(self.time)
        buf += "\n%s;Energy(J):" % self.name + str(self.energy)
        buf += "\n%s;Power(W):" % self.name + str(self.power)
        buf += "\n%s;Memory(GB):" % self.name + str(self.memory)
        return buf

# Helper function to separate values
def plunk(lst,vals):
    if isinstance(vals,list):
        map(lambda x: lst.append(x), vals)
    else:
        lst.append(vals)

class Network:
    def __init__(self,paramstr):
        global phases,cpus
        self.id = paramstr
        self.experiments = []
        self.summary = {}

    def extendData(self,experiment):
        self.experiments.append(experiment)
    


    def summarize(self,what):
        # what is one of time, power, energy, memory
        k = self.id
        threads = k.split("_")[-1].strip('t')
        ins0 = []; ins1 = []; dels0 =[]; dels1=[]; mem = []; root0=[]; root1=[]
        galois0 = []; galois1=[]; galois_mem = []
        
        for e in self.experiments:
            if what.lower() in ['time','speedup'] : data = e.time
            if what.lower() == 'energy': data = e.energy
            if what.lower() == 'power': data = e.power
            if what.lower() == 'memory': data = e.memory
            if data.get("Galois-All"):
                #galois.append(dict(zip(cores,data["Galois-All"]))) # pairs of values (cpu0,cpu1)
                plunk(galois0,data["Galois-All"][0])
                plunk(galois1,data["Galois-All"][1])
            if what.lower() == 'memory' and data.get("galois-Total memory"):
                galois_mem.append(data["galois-Total memory"]) # single value for both CPUs
            if data.get("MST-Insert") and data.get("MST-Delete") and data.get("MST-Rooted"):
                plunk(ins0,data["MST-Insert"][0]) # pairs of floats
                plunk(ins1,data["MST-Insert"][1])
                plunk(dels0,data["MST-Delete"][0]) # pairs of floats
                plunk(dels1,data["MST-Delete"][1])
                plunk(root0,data["MST-Rooted"][0])
                plunk(root1,data["MST-Rooted"][1])
            if what.lower() == 'memory' and data.get("mst-Total memory"):
                mem.append(data["mst-Total memory"]) # single value for both CPUs
        self.summary = {'Experiment': k, 'what': what, 'Threads':threads,
                        'Insertion-pkg0':ins0,'Insertion-pkg1':ins1,
                        'Deletion-pkg0':dels0,'Deletion-pkg1':dels1,
                        'BuildRootedTree-pkg0':root0,'BuildRootedTree-pkg1':root1,
                        'Galois-pkg0':galois0, 'Galois-pkg1': galois1,
                        'Memory':mem,'Galois-mem':galois_mem}
        return self.summary


    def __repr__(self):
        buf = "\nNetwork %s: " % self.id
        if self.experiments:
            buf += "\n" +  "\n".join([str(exp) for exp in self.experiments]) + "\n"
        else:
            buf += "No successful experiments.\n"
        return buf
        
    
    def dump(self):
        print(self.experiments)


def processLog(logpath,networks):
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
    phase = None; time = [0]*2; energy=[0]*2; power=[0]*2; memory=0
    contents = open(logpath,'r').read()
    if contents.find("Command being timed:") < 0:
        phases["STAT,(NULL),Time"] = "DONE"
        phases["Total Time for Updating"] = "DONE"
    lines = contents.split('\n')
    new = True; num =0
    for line in lines:
        if new:
            experiment = Experiment(which,paramstr,num)
            new = False
        line = line.strip()
        if line.startswith("Found"): continue
        if line.startswith("Time Taken for Initializing") or \
           line.startswith("Galois Benchmark Suite"):
            phase = None
            new = True
        s = line.split()
        
        for p in phases.keys():
            #print(p,line)
            if line.startswith(p):
                if phase: experiment.set(num,which,phase,time,energy,power,memory)
                phase = phases[p]  # new phase
                time = [0]*2; energy=[0]*2; power=[0]*2; memory=0
                #print("New phase: ",phase)
                break

        if not phase: continue
        if phase == "Total memory":
            if line.find("Maximum resident set size")>=0:
                memory = float(line.split(":")[-1].strip())/1048576.0

        if phase == "DONE":
            phase = None
            if sum(list(experiment.time['MST-Insert'])) or sum(list(experiment.time['Galois-All'])):
                networks[paramstr].extendData(experiment)
                num += 1
            

        if line.find("rapl:::PACKAGE_ENERGY:PACKAGE") < 0: continue

        # See more complete example RAPL output at bottom of file
        # 2.9492 s 195.8815 (* Total Energy for rapl:::PACKAGE_ENERGY:PACKAGE0 *)
        if phase and line.find("rapl:::PACKAGE_ENERGY:PACKAGE") > 0:
            #print(logpath,line)
            pkg = int(s[-2][-1])
            if not time[pkg]: time[pkg]=float(s[0])
            if line.find("Total Energy for rapl:::PACKAGE_ENERGY:PACKAGE")>0:
                energy[pkg]=float(s[2])
            if line.find("Average Power for rapl:::PACKAGE_ENERGY:PACKAGE")>0:
                power[pkg]=float(s[2])


def processLogs(logdir):
    global phases
    networks = {}
    logfiles = glob.glob(logdir+"/*.log")
    for logpath in logfiles:
        processLog(logpath,networks)
    return networks

def main():
    global alldata
    if len(sys.argv) < 2:
        usage()
        sys.exit(1)
    logdir = sys.argv[1]
    if not os.path.exists(logdir):
        print("Error: invalid path %s" % logdir)
        usage()
        sys.exit(1)
    pp = pprint.PrettyPrinter(indent=2)

    networks = processLogs(logdir)
    summaries = []
    for n in networks.values():
        #print(n)
        for what in ["Time","Energy","Power","Memory"]:
            summaries.append(n.summarize(what))
    #for summary in summaries: merge(summary)
    pp.pprint(summaries)



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




