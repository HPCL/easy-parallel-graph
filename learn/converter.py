from pandas import DataFrame, read_csv
import matplotlib.pyplot as plt
import pandas as pd 
import numpy as np
import re 
file = r'combined-talapas.csv'
df = pd.read_csv(file);

df1=df['package']

number_of_cols=np.max(df1)+1

temp=3
one_hot_package=np.eye(number_of_cols)[df1]

se = pd.DataFrame(one_hot_package)

merged =pd.concat([se,df], axis=1)

merged=merged.drop('package',1)
#print merged


s = 'Name(something)'
temp= re.search('\(([^)]+)', s).group(1)
#print temp
#df = df.fillna('')

#print df['Nodes.in.largest.WCC']
df['Nodes.in.largest.WCC']=df['Nodes.in.largest.WCC'].astype(str) #converting to string

#df['Nodes.in.largest.WCC']=df['Nodes.in.largest.WCC'].apply(lambda x: re.search('\(([^)]+)', x) if(np.all(pd.notnull(x))) else x .group(1))  #Keeping parantheses




#df['Nodes.in.largest.WCC']=df['Nodes.in.largest.WCC'].apply(lambda x: re.search('\(([^)]+)', x).group(1) if(pd.notnull(x[0])) else x)

#df['Nodes.in.largest.WCC']=re.sub('[(){}<>]', '', df['Nodes.in.largest.WCC'])
nwcc=[]
nscc=[]
ewcc=[]
escc=[]

#print df['Nodes.in.largest.WCC']

for index, row in df.iterrows():
    try:
    	row['Nodes.in.largest.WCC']=re.search('\(([^)]+)', row['Nodes.in.largest.WCC']).group(1)
    	nwcc.append(row['Nodes.in.largest.WCC'])
    except: 
    	row['Nodes.in.largest.WCC']=None
    	nwcc.append(row['Nodes.in.largest.WCC'])
    	pass

    try:
    	row['Nodes.in.largest.SCC']=re.search('\(([^)]+)', row['Nodes.in.largest.SCC']).group(1)
    	nscc.append(row['Nodes.in.largest.SCC'])
    except: 
    	row['Nodes.in.largest.SCC']=None
    	nscc.append(row['Nodes.in.largest.SCC'])
    	pass

    try:
    	row['Edges.in.largest.WCC']=re.search('\(([^)]+)', row['Edges.in.largest.WCC']).group(1)
    	ewcc.append(row['Edges.in.largest.WCC'])
    except: 
    	row['Edges.in.largest.WCC']=None
    	ewcc.append(row['Edges.in.largest.WCC'])
    	pass

    try:
    	row['Edges.in.largest.SCC']=re.search('\(([^)]+)', row['Edges.in.largest.SCC']).group(1)
    	escc.append(row['Edges.in.largest.SCC'])
    except: 
    	row['Edges.in.largest.SCC']=None
    	escc.append(row['Edges.in.largest.SCC'])
    	pass

merged['Nodes.in.largest.WCC']=pd.Series(nwcc)
merged['Nodes.in.largest.SCC']=pd.Series(nscc)
merged['Edges.in.largest.WCC']=pd.Series(ewcc)
merged['Edges.in.largest.SCC']=pd.Series(escc)

merged.columns = merged.columns.astype(str)
merged.rename(columns={'0':'package0','1':'package1','2':'package2','3':'package3','4':'package4'}, inplace=True)
print merged

merged.to_csv('clean.csv',na_rep='NA',index=False)



    #index['Nodes.in.largest.WCC']=row['Nodes.in.largest.WCC']	


#df['Nodes.in.largest.WCC']=df['Nodes.in.largest.WCC'].dropna(inplace=True)
#print df['Nodes.in.largest.WCC']