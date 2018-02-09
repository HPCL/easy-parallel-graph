
# coding: utf-8

# In[1]:

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import sys
#get_ipython().magic('matplotlib inline')
#plt.rcParams.update({'font.size': 16})


# In[2]:

algs = ['CC','MST']
whats = ['Total CPU Energy (J)','Average CPU Power (W)']
epvs = ['8','16']
nws = ['ER','G']
insperc = ['100','75']


# In[13]:

def genBoxPlot(insertion, deletion, filename, title,galois):
    # Create a dataframe and plot
    columns = ['Key','Threads',alg+'-ins',alg+'-del']
    if galois: columns = ['Key','Threads',alg+'-ins',alg+'-del','Galois']
    df = pd.DataFrame(columns = columns)
    for k,v in insertion.items():
      threads = int(k.split('_')[-1])
      if galois:
          for ind in range( min( len(insertion[k]), len(galois[k]) ) ):
            df2 = pd.DataFrame([ [ k, threads, insertion[k][ind], deletion[k][ind], galois[k][ind]] ], columns=columns)
      else:
          for ind in range( min( len(insertion[k]), len(deletion[k]) ) ):
            df2 = pd.DataFrame([ [k, threads, insertion[k][ind], deletion[k][ind]] ], columns=columns)
      df = df.append(df2, ignore_index=True)

    if df.empty: 
        print(filename, ': No data')
        return
    print(df.head(10).to_string())

    if galois:
        dd=pd.melt(df,id_vars=['Threads'],value_vars=[alg+'-ins',alg + '-del','Galois'],var_name='Operation')
    else:
        dd=pd.melt(df,id_vars=['Threads'],value_vars=[alg+'-ins',alg + '-del'],var_name='Operation')
    
    #ax = sns.boxplot(x='Threads',y='value',data=dd,hue='Operation',palette="Set2") # also swarmplot
    ax = sns.pointplot(x='Threads',y='value',data=dd,hue='Operation',palette="Set2",markers=["^", "o","*"],linestyles=["-", "--", ":"])
    ax.patch.set_alpha(0.5)
    plt.ylabel(what)
    plt.title(title)

    plt.savefig(fname)
    #plt.show()

    
#===========================================================================
# Generate plots for the different networks, epv, and insertion percentatges
#===========================================================================
# Uncomment the following two lines and comment out the first for loop to have single plots for both network types
#nw=None  
#if True:

for nw in nws:
    for alg in algs:
        fname = alg.lower() + '/parsed-power-aggregate.txt'
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
                        # Filter by epv, network type, insertion percentage
                        if parts[3] != epv: continue
                        if nw and parts[4] != nw: continue
                        if parts[5] != ins: continue
                        key = '_'.join(parts[2:8])
                        if parts[0] == 'algorithm': continue # Header
                        if parts[0] == 'Galois':
                            if parts[1] == 'All' and parts[8].startswith(what):
                                if not key in galois.keys(): galois[key] = []
                                galois[key].append(float(parts[-1]))
                        if parts[0] == alg and parts[-2].startswith(what):
                            if parts[1] == 'insertion':
                                if not key in insertion.keys(): insertion[key] = []
                                insertion[key].append(float(parts[-1]))
                            elif parts[1] == 'deletion':
                                if not key in deletion.keys(): deletion[key] = []
                                deletion[key].append(float(parts[-1]))

                    #fname = '_'.join([alg,nw,epv,ins,what.replace(' ','')])
                    if nw: fname = '_'.join([alg,nw,epv,ins,what.replace(' ','')])
                    else: fname = '_'.join([alg,epv,ins,what.replace(' ','')])
                    if galois: fname += '_Galois'
                    fname += '.pdf'
                    title = alg + ': RMAT-24'
                    if nw: title += ' (%s)' %nw
                    title += ', %s edges per vertex, %s%% insertions' % (epv,ins)
                    genBoxPlot(insertion,deletion,fname,title,galois)


# In[ ]:



