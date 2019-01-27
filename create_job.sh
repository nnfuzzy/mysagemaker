#! /usr/bin/bash


JOB_NAME=$1
IMAGE_NAME=$2
ROLE=arn:aws:iam::058300292687:role/service-role/AmazonSageMaker-ExecutionRole-20190115T222446
BUCKET=mymodels201901
MODEL_NAME=
ENDPOINT_CONFIG_NAME=
ENDPOINT_NAME=

aws sagemaker create-training-job \
    --training-job-name $JOB_NAME \
    --algorithm-specification \
        TrainingImage=$IMAGE_NAME:latest,TrainingInputMode=File \
    --role-arn $ROLE \
    --input-data-config \
        '{"ChannelName":"training",
          "DataSource":{"S3DataSource":{"S3DataType":"S3Prefix",
                                        "S3Uri":"s3://mymodels201901/data/training/",
                                        "S3DataDistributionType":"FullyReplicated"
                                        }
                        }
          }' \
    --output-data-config \
        S3OutputPath=s3://$BUCKET/models/ \
    --resource-config \
        InstanceType=ml.m4.xlarge,InstanceCount=1,VolumeSizeInGB=1 \
    --stopping-condition \
        MaxRuntimeInSeconds=86400 \
    --hyper-parameters \
        max_leaf_nodes=5


aws sagemaker create-model \
    --model-name $MODEL_NAME \
    --primary-container \
        Image=$IMAGE_NAME:latest,ModelDataUrl=s3://$BUCKET/models/$JOB_NAME/output/model.tar.gz \
    --execution-role-arn $ROLE


aws sagemaker create-endpoint-config \
    --endpoint-config-name $ENDPOINT_CONFIG_NAME \
    --production-variants \
        VariantName=dev,ModelName=$MODEL_NAME,InitialInstanceCount=1,InstanceType=ml.m4.xlarge,InitialVariantWeight=1.0

aws sagemaker create-endpoint \
    --endpoint-name $ENDPOINT_NAME  \
    --endpoint-config-name $ENDPOINT_CONFIG_NAME