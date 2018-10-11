import pandas
import numpy as np
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.linear_model import Ridge, LinearRegression
from sklearn.svm import SVC
from sklearn import preprocessing


#-----------input-------
print(np.finfo(float))
datafile="petsc_mfree_MOOSE_artemis_p1_30_30.csv"
data = pandas.read_csv(datafile)
#---------remove bad experiments-----
data=data[data.label == 'good']
data.to_csv('pre_data.csv',na_rep='NaN',index=False)

