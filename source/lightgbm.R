# A quick and dirty lightgbm run. Still need to do parameter tuning and cv

library(data.table)
library(lightgbm)

# read data
dtrain <- fread('../input/train.csv', drop = 'MachineIdentifier')
dtest <- fread('../input/test.csv')

# check size in memory
print(object.size(dtrain), units='Gb')
print(object.size(dtest), units='Gb')

#sample 1/2 of training data. Will optimize later so we can use all of the data
rows = sample(1:nrow(dtrain), size = nrow(dtrain)/2, replace=FALSE)

#set dtrain to only sample rows
dtrain <- dtrain[rows, ]
print(object.size(dtrain), units='Gb')

#assign target variable to y_train
y_train <- dtrain$HasDetections
dtrain[, HasDetections := NULL]

# assign test data ids to id_test
id_test <- dtest$MachineIdentifier
dtest[, MachineIdentifier := NULL]

# save # rows in dtrain and dtest
nrow_dtrain <- nrow(dtrain)
nrow_dtest <- nrow(dtest)

# combine dtrain and dtest for preprocessing
alldata <- rbindlist(list(dtrain, dtest))

# remove dtrain and dtest
rm(dtrain, dtest)
gc()

# get vector of character columns
char_cols <- names(which(sapply(alldata, class) == 'character'))

# convert character columns to integer
alldata[, (char_cols) := lapply(.SD, function(x) as.integer(as.factor(x))), .SDcols = char_cols]

# split back into dtrain and dtest
dtrain <- alldata[1:nrow_dtrain, ]
dtest <- alldata[(nrow_dtrain+1):nrow(alldata)]

rm(alldata); gc();

# Set up processed data for lgbm
x_train <- lgb.Dataset(data = data.matrix(dtrain), label = y_train)
x_test <- data.matrix(dtest)

rm(dtrain, dtest); gc();

params = list(
    boosting_type = 'gbdt', 
    objective = 'binary',
    metric = 'auc', 
    nthread = 4, 
    learning_rate = 0.05, 
    max_depth = 5,
    num_leaves = 40,
    sub_feature = 0.7, 
    sub_row = 0.7, 
    bagging_freq = 1,
    lambda_l1 = 0.1, 
    lambda_l2 = 0.1
)

# train model
lgbm_mod <- lgb.train(params = params,
                      nrounds = 1000,
                      data = x_train, 
                      verbose = 1
    )

# make predictions
preds <- predict(lgbm_mod, data = x_test)

# set up submission frame
sub <- data.table(
    MachineIdentifier = id_test,
    HasDetections = preds
)

# write to disk
fwrite(sub, file = 'submission_lgbm.csv', row.names = FALSE)