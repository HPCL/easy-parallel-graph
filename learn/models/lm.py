# Modified from 
# https://github.com/LighthouseHPC/lighthouse/tree/master/sandbox/ml/scikit
import sys
import numpy as np
import pandas
import math
import seaborn
from sklearn import linear_model
from sklearn.model_selection import train_test_split
from sklearn.linear_model import Ridge
if len(sys.argv) != 2:
    print("usage: python {} datafile.csv".format(sys.argv[0]))
    sys.exit(2)
datafile = sys.argv[1]

data = pandas.read_csv(datafile)

#Convert nominal to numeric
data['package'] = data.package.astype('category')
data['algorithm'] = data.algorithm.astype('category')
#data['dataset'] = data.dataset.astype('category')
cat_columns = data.select_dtypes(['category']).columns
data[cat_columns] = data[cat_columns].apply(lambda x: x.cat.codes)
data=data.dropna()

#Train test split:
data.dropna(axis=1, how='any', inplace=True)
a = len(data.T) - 1 # The last column is the label
X = data.iloc[:, range(0,a)]
Y = data.iloc[:,a]
X_train, X_test, Y_train, Y_test = train_test_split(X,Y, test_size = 0.34)

#fit linear model:
lm = linear_model.LinearRegression()
lm.fit(X_train, Y_train)
pred=lm.predict(X_test)

#Get scores and analysis
score_r = lm.score(X_test, Y_test)

print("Model = {}, R^2 = {}".format(lm.get_params(), score_r))

seaborn.set_style("whitegrid")

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
