import pandas
import numpy as np
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.linear_model import Ridge, LinearRegression
from sklearn.svm import SVC
from sklearn import preprocessing



#-----------input-------
datafile="pre_data.csv"
data = pandas.read_csv(datafile)
#-----------------Convert nominal to numeric:---------
data['matrix_name'] = data.matrix_name.astype('category')
data['label'] = data.label.astype('category')
cat_columns = data.select_dtypes(['category']).columns
data[cat_columns] = data[cat_columns].apply(lambda x: x.cat.codes)

#-----------------Push time to last and remove outliers ----------------------------

cols = list(data.columns.values) #Make a list of all of the columns in the df
cols.pop(cols.index('time')) #Remove time from list
data = data[cols+['time']] #Create new dataframe with columns in the order you want
data=data.dropna()
data=data[data.time < 1e308]

#----------------Convert data types to float-----------
for i in cols:
	data[i]=data[i].astype(np.float64)
#----------------Train test split:------------
a = len(data.T) - 1 # The last column is the label
X = data.iloc[:, list(range(0,a))]
Y = data.iloc[:,a]
x=pandas.DataFrame(X)
y=pandas.DataFrame(Y)


indices=np.arange(len(data))
data['time']=data['time']
data.insert(loc=0, column='index', value=indices)
data.to_csv('data.csv',na_rep='NaN',index=False)

X_train, X_test, Y_train, Y_test, indices_train, indices_test = train_test_split(x,y,indices, test_size = 0.34)


# Y_test = pandas.read_csv('y_test.csv')
# Y_train = pandas.read_csv('y_train.csv')
# X_test = pandas.read_csv('x_test.csv')
# X_train = pandas.read_csv('x_train.csv')
# indices_train=pandas.read_csv('indices_train.csv')
# indices_test=pandas.read_csv('indices_test.csv')


Y_test_temp=Y_test
Y_train_temp=Y_train
X_test_temp=X_test
X_train_temp=X_train


#----------------fit ridge model:-----------
print("fitting model...")
min_max_scaler = preprocessing.MinMaxScaler()
X_scaled = min_max_scaler.fit_transform(X_train)
Y_scaled = min_max_scaler.fit_transform(Y_train)

np.savetxt('ytest.csv', X_scaled, delimiter=',')
#reg = LinearRegression().fit(X_scaled, Y_scaled)
model=Ridge(alpha = 1,fit_intercept=True).fit(X_train, Y_train)
pred=model.predict(X_test)




#-------------Get scores and analysis----------
score_r = model.score(X_test, Y_test)
print(("Model = {}, R^2 = {}".format(model.get_params(), score_r)))
Y_test.to_csv('ytest.csv',na_rep='NA',index=False)


actual=[]
actual=Y_test
result=pandas.DataFrame(columns=['actual','pred','diff'],index=list(range(1,len(Y_test))))
result['pred']=pandas.DataFrame(pred)
result['actual']=pandas.read_csv('ytest.csv')
result['diff']=result['actual']-result['pred']
#result['index'] = pandas.Series(indices_test, index=X_test_temp.index)
result.to_csv('predictions.csv',na_rep='N',index=False)


Y_test_temp['index'] = pandas.Series(indices_test, index=Y_test_temp.index)
X_test_temp['index'] = pandas.Series(indices_test, index=X_test_temp.index)
Y_train_temp['index'] = pandas.Series(indices_train, index=Y_train_temp.index)
X_train_temp['index'] = pandas.Series(indices_train, index=X_train_temp.index)
Y_test_temp['pred'] = pred #pandas.Series(pred, index=Y_test_temp.index)
 
Y_test_pred_sorted=Y_test_temp.sort_values(by=['pred'])
Y_test_actual_sorted=Y_test_temp.sort_values(by=['time'])
#Y_test_pred_sorted.to_csv('temp.csv',na_rep='NA',index=False)
#Y_test_actual_sorted.to_csv('temp1.csv',na_rep='NA',index=False)


speed_loss=[]
for i,actual_index in enumerate(Y_test_actual_sorted['index']):
	speed_loss.append(Y_test_actual_sorted['time'].iloc[i]-Y_test_pred_sorted['time'].iloc[i])

print("calculating rank and speed loss... ")

rank_loss=[]
for i,val_actual in enumerate(Y_test_actual_sorted['index']):
	for j,val_pred in enumerate(Y_test_pred_sorted['index']):
		if val_pred==val_actual:
			rank_loss.append(j-i)

print("Results dumped to files...")

rank_results=pandas.DataFrame(columns=['rank','speed_loss','rank_loss'],index=list(range(0,len(speed_loss))))
rank_results['rank']=np.arange(len(speed_loss))
rank_results['speed_loss']=pandas.Series(speed_loss)
rank_results['rank_loss']=pandas.Series(rank_loss)
rank_results.to_csv('rank_results.csv',na_rep='NA',index=False)


plt.plot(Y_test_actual_sorted['time'], abs(rank_results['rank_loss']))
plt.xlabel("Time (s)")
plt.ylabel("rank loss")
plt.show()
