
# coding: utf-8

# In[1]:

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns     # you can install this with "pip install seaborn"
import sys
get_ipython().magic('matplotlib inline')
#plt.rcParams.update({'font.size': 16})


# In[11]:

algs = ['MST/output-16epv','MST/output-8epv','MST/output-real','CC/output-16epv','CC/output-8epv','CC/output-real']
whats = ['Total CPU Energy (J)','Average CPU Power (W)']
epvs = ['8','16']
nws = ['ER','G']
insperc = ['100','75']
sleep_power={1:35.59980, 2:32.50874, 4:39.00752, 8:27.53429, 16:29.59654, 24:26.78392, 
             32:28.23629, 40:29.28156, 48:29.53099, 56:27.61415, 64:25.24939, 72:29.56577}
sleep_energy={1:356.00497, 2:325.09772, 4:390.13837, 8:275.48913, 16:296.30119, 24:268.22497, 
             32:283.00666, 40:293.51369, 48:296.04856, 56:276.91622, 64:253.14684, 72:296.29419}


# In[13]:

def genBoxPlot(what,insertion, deletion, filename, title,galois=None):
    baseline=[]
    if what=='Average CPU Power (W)': baseline = sleep_power
    if galois:
        if baseline: columns = ['Key','Threads','Baseline', alg+'-ins',alg+'-del','Galois']
        else: columns = ['Key','Threads', alg+'-ins',alg+'-del','Galois']
    else:
        if baseline: columns = ['Key','Threads','Baseline', alg+'-ins',alg+'-del']
        else: columns = ['Key','Threads', alg+'-ins',alg+'-del']
    df = pd.DataFrame(columns = columns)
    for k,v in insertion.items():
        threads = int(k.split('_')[-1])
        if galois:
            for ind in range( min( len(insertion[k]), len(galois[k]) ) ):
                if baseline:
                    df2 = pd.DataFrame([ [ k, threads, baseline[threads],insertion[k][ind], deletion[k][ind], galois[k][ind]] ], columns=columns)
                else:
                    df2 = pd.DataFrame([ [ k, threads, insertion[k][ind], deletion[k][ind], galois[k][ind]] ], columns=columns)
        else:
            for ind in range( min( len(insertion[k]), len(deletion[k]) ) ):
                if baseline: df2 = pd.DataFrame([ [k, threads, baseline[threads], insertion[k][ind], deletion[k][ind]] ], columns=columns)
                else: df2 = pd.DataFrame([ [k, threads, insertion[k][ind], deletion[k][ind]] ], columns=columns)
        df = df.append(df2, ignore_index=True)

    if df.empty: 
        print(filename, ': No data')
        return
    print(df.head(10).to_string())

    if galois:
        if baseline: dd=pd.melt(df,id_vars=['Threads'],value_vars=['Baseline', alg+'-ins',alg + '-del','Galois'],var_name='Operation')
        else: dd=pd.melt(df,id_vars=['Threads'],value_vars=[alg+'-ins',alg + '-del','Galois'],var_name='Operation')
    else:
        if baseline: dd=pd.melt(df,id_vars=['Threads'],value_vars=['Baseline', alg+'-ins',alg + '-del'],var_name='Operation')
        else: dd=pd.melt(df,id_vars=['Threads'],value_vars=[alg+'-ins',alg + '-del'],var_name='Operation')
    
    #ax = sns.boxplot(x='Threads',y='value',data=dd,hue='Operation',palette="Set2") # also swarmplot
    if baseline:
        ax = sns.pointplot(x='Threads',y='value',data=dd,hue='Operation',palette="Set2",markers=['.',"^", "o","*"],linestyles=['none',"-", "--", ":"])
    else:
        ax = sns.pointplot(x='Threads',y='value',data=dd,hue='Operation',palette="Set2",markers=["^", "o","*"],linestyles=["-", "--", ":"])
    ax.patch.set_alpha(0.5)
    plt.ylabel(what)
    plt.title(title)

    plt.savefig(fname)
    plt.show()

for nw in nws:
    for algfull in algs:
        fname = algfull.lower() + '/parsed-power-aggregate.txt'
        alg = algfull.split('/')[0]
        lines = open(fname).readlines()
        for what in whats:
            for epv in epvs:
                for ins in insperc:
                    galois={}
                    insertion = {}
                    deletion = {}
                    for line in lines:
                        #algorithm,execution_phase,scale,edges_per_vertex,RMAT_type,insertion_percent,changed_vertices,threads,measurement,value
                        parts = line.strip().split(',')
                        #print(what,parts)
                        # Filter by epv, network type, insertion percentage
                        if parts[3] != epv: continue
                        if parts[4] != nw: continue
                        if parts[5] != ins: continue
                        key = '_'.join(parts[2:8])
                        if parts[0] == 'algorithm': continue # Header
                        if parts[0] == 'Galois':
                            if parts[1] == 'All' and parts[-2].startswith(what):
                                if not key in galois.keys(): galois[key] = []
                                galois[key].append(float(parts[-1]))
                        if parts[0] == alg and parts[-2].startswith(what):
                            if parts[1] == 'insertion':
                                if not key in insertion.keys(): insertion[key] = []
                                insertion[key].append(float(parts[-1]))
                            elif parts[1] == 'deletion':
                                if not key in deletion.keys(): deletion[key] = []
                                deletion[key].append(float(parts[-1]))
                    #print(galois)
                    #fname = '_'.join([alg,nw,epv,ins,what.replace(' ','')])
                    if nw: fname = '_'.join([alg,nw,epv,ins,what.replace(' ','')])
                    else: fname = '_'.join([alg,epv,ins,what.replace(' ','')])
                    if galois: fname += '_Galois'
                    fname += '.pdf'
                    title = alg + ': RMAT-24'
                    if nw: title += ' (%s)' %nw
                    title += ', %s edges per vertex, %s%% insertions' % (epv,ins)
                    genBoxPlot(what,insertion,deletion,fname,title,galois)


# In[ ]:



