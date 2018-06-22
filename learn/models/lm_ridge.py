# Modified from 
# https://github.com/LighthouseHPC/lighthouse/tree/master/sandbox/ml/scikit
import sys
import numpy as np
import pandas
import math
from scipy import stats
import statsmodels.api as sm
import matplotlib.pyplot as plt
from sklearn import linear_model
from sklearn.model_selection import train_test_split
from sklearn.linear_model import Ridge

#Read dalfile and store it it as pandas dataframe
if len(sys.argv) != 2:
    print("usage: python {} datafile.csv".format(sys.argv[0]))
    sys.exit(2)
datafile = sys.argv[1]
data = pandas.read_csv(datafile)
rf=pandas.read_csv("rf_trained.csv")

#Convert nominal to numeric:
data['package'] = data.package.astype('category')
data['algorithm'] = data.algorithm.astype('category')
#data['dataset'] = data.dataset.astype('category')
cat_columns = data.select_dtypes(['category']).columns
data[cat_columns] = data[cat_columns].apply(lambda x: x.cat.codes)
data=data.dropna()


#Train test split:
#data.dropna(axis=1, how='any', inplace=True)
a = len(data.T) - 1 # The last column is the label
X = data.iloc[:, range(0,a)]
Y = data.iloc[:,a]
X_train, X_test, Y_train, Y_test = train_test_split(X,Y, test_size = 0.34)

#fit Random forest model:
model=Ridge(alpha = 1).fit(X_train, Y_train)
pred=model.predict(X_test)

#Get scores and analysis
score_r = model.score(X_test, Y_test)
print("Model = {}, R^2 = {}".format(model.get_params(), score_r))
print score_r

#rf_tresting--------------------------

rf=rf[['dataset', 'package','algorithm', 'nvertices','nedges','nthreads','Nodes.in.largest.WCC','Edges.in.largest.WCC','Nodes.in.largest.SCC', 'Edges.in.largest.SCC', 'Average.clustering.coefficient', 'Number.of.triangles', 'Fraction.of.closed.triangles', 'Diameter..longest.shortest.path.', 'X90.percentile.effective.diameter',  'classif', 'runtime']]


df1=rf
df1.sort_values(by=['runtime'],ascending=True, inplace=True)
df1['runtime'].to_csv("actual_runtime.csv")
rf=rf.drop(['runtime'], axis=1)
rf=rf.drop(['classif'], axis=1)
rf=rf.drop(['dataset'], axis=1)
pred_new=model.predict(rf)
#print pred_new
pred_new=np.sort(pred_new)

df = pandas.DataFrame(pred_new)
df.to_csv("pred_new.csv")

#Get scores and analysis
# score_rf_new = model.score(rf, Y_test)
# print("Model = {}, R^2 = {}".format(model.get_params(), score_r))
# print score_r


# X_test1.to_csv('xtest.csv',na_rep='NA',index=False)
# X_test1['dataset'].to_csv('ytest.csv',na_rep='NA',index=False)
#print model.coef_
#print X_test.columns
#print zip(model.coef_, X_test.columns)	

#print pred
#print Y_test


NRMSD = (pred - Y_test)**2 / (pred.mean() * Y_test.mean())
NRMSD = NRMSD.mean()
print "NRMSD:"
print NRMSD

RMSD = (pred - Y_test)**2
RMSD = RMSD.mean()
RMSD = math.sqrt(RMSD)
print "RMSD:"
print RMSD

# y_sd = np.std(Y_test)
# temp = 1 - score_r
# temp = math.sqrt(temp)
# RMSD = temp*y_sd
# print y_sd