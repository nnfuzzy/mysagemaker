#!/usr/bin/env zsh


JOB_NAME=multilinear-job-4
#IMAGE_NAME=058300292687.dkr.ecr.eu-central-1.amazonaws.com/lreg201901
IMAGE_NAME=190332596061.dkr.ecr.eu-central-1.amazonaws.com/lreg201901:latest
#ROLE=arn:aws:iam::058300292687:role/service-role/AmazonSageMaker-ExecutionRole-20190115T222446
ROLE=arn:aws:iam::190332596061:role/service-role/AmazonSageMaker-ExecutionRole-20190122T130631
BUCKET=multilinear201901w
MODEL_NAME=multilinear201901-models
ENDPOINT_CONFIG_NAME=multi-linear-config
ENDPOINT_NAME=multi-linear-endpoint
#ENDPOINT_INSTANCE=ml.m4.xlarge
ENDPOINT_INSTANCE=ml.t2.xlarge


while [ ! $# -eq 0 ]
do
    case "$1" in
        --help | -h)
               echo "Bidon execute commands"
                echo " "
                echo "options:"
                echo "-h, help show brief help"
                echo "-b, create bucket and import train data"
                echo "-j, create job"
                echo "-m, create model"
                echo "-e, create endpoint"
                exit 0
            exit
            ;;

         --bucker | -b)
         aws s3 mb s3://$BUCKET
         aws s3api put-object --bucket $BUCKET --key data/training/ --body data/train_multi_model.csv


        exit
        ;;

         --job | -j)

                aws sagemaker create-training-job \
                    --training-job-name $JOB_NAME \
                    --algorithm-specification \
                        TrainingImage=$IMAGE_NAME,TrainingInputMode=File \
                    --role-arn $ROLE \
                    --input-data-config \
                        '{"ChannelName":"training",
                          "DataSource":{"S3DataSource":{"S3DataType":"S3Prefix",
                                                        "S3Uri":"s3://multilinear201901w/data/training/",
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
                        n_iter=100



        exit
        ;;


        --model | -m)

             aws sagemaker create-model \
            --model-name $MODEL_NAME \
            --primary-container Image=$IMAGE_NAME,ModelDataUrl=s3://$BUCKET/models/$JOB_NAME/output/model.tar.gz \
            --execution-role-arn $ROLE

        exit
        ;;


        --endpoint | -e)

        aws sagemaker create-endpoint-config \
    --endpoint-config-name $ENDPOINT_CONFIG_NAME \
    --production-variants \
        VariantName=dev,ModelName=$MODEL_NAME,InitialInstanceCount=1,InstanceType=$ENDPOINT_INSTANCE,InitialVariantWeight=1.0


     aws sagemaker create-endpoint \
    --endpoint-name $ENDPOINT_NAME  \
    --endpoint-config-name $ENDPOINT_CONFIG_NAME


        exit
        ;;


    esac
    shift
done