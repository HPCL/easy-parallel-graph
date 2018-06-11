import numpy as np
import matplotlib.pyplot as plt
import sys
import pandas
from sklearn import preprocessing
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn import metrics
from sklearn.metrics import confusion_matrix
from sklearn.preprocessing import MinMaxScaler
from sklearn.metrics import classification_report



if len(sys.argv) != 2:
    print("usage: python {} datafile.csv".format(sys.argv[0]))
    sys.exit(2)
datafile = sys.argv[1]


data = pandas.read_csv(datafile)
target_names = ['good','bad']

#Convert nominal to numeric:


classification=[]
#data['runtime'] = data['runtime'].apply(lambda x: x*1000)

df= data[(data !=0).all(1)]
df.to_csv('df.csv',na_rep='NA',index=False)
data=df

# for index, row in data.iterrows():
#     if row['runtime'] <0.4:
        
    


#m=data['runtime'].mean()
m = data['nedges'].divide(data['runtime']).mean()
print m
#print data['runtime']
for index, row in data.iterrows():
    if row['nedges']/row['runtime'] < m/1000:
        row['classification']='good'
        classification.append(row['classification'])
    else:
        row['classification']='bad'
        classification.append(row['classification'])


data['classif']=pandas.Series(classification)
#print data['classif']

data['package'] = data.package.astype('category')
data['algorithm'] = data.algorithm.astype('category')
data['dataset'] = data.dataset.astype('category')
cat_columns = data.select_dtypes(['category']).columns
data[cat_columns] = data[cat_columns].apply(lambda x: x.cat.codes)
data=data.dropna()
data['classif'].to_csv('classif.csv',na_rep='NA',index=False)

data=data.drop('runtime', axis=1)
#data=data.drop('Unnamed: 0', axis=1)
data=data.drop('dataset', axis=1)
#print data
data.to_csv('data_new.csv',na_rep='NA',index=False)
#data[['nedges', 'nvertices']] = scaler.fit_transform(data[['nedges', 'nvertices']])


data.dropna(axis=1, how='any', inplace=True)
a = len(data.T) - 1 # The last column is the label
X = data.iloc[:, range(0,a)]



Y = data.iloc[:,a]
X_train, X_test, Y_train, Y_test = train_test_split(X,Y, test_size = 0.34)

#print Y_test



model = LogisticRegression()
model = model.fit(X_train, Y_train)
#predictions = model.predict(X_test)
predictions = model.predict(X_test)
cm = confusion_matrix(Y_test, predictions)

#results = metrics.classification_report(Y_test, predictions, target_names)
results = metrics.classification_report(Y_test, predictions, target_names)
print results
print "confusion matrix:"
print cm

# plt.scatter(predictions,Y_test)
# plt.show()
#print X_train.head()
#print predictions