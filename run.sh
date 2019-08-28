#!/bin/bash

# MLTK=/Users/yin_lou/repos/mltk-github/mltk/target/mltk-0.1.0-SNAPSHOT.jar
MLTK="/home/stefanhgm/Code/mltk/target/mltk-0.1.0-SNAPSHOT.jar"

function usage() {
    echo "./run_mltk.sh"
    echo "\t-h --help"
    echo "\t--all=$ALL_DATA"
    echo "\t--train=$TRAIN_DATA"
    echo "\t--valid=$VALID_DATA"
    echo "\t--test=$TEST_DATA"
    echo "\t--attr=$ATTRIBUTES"
    echo "\t--i1=$ITERATIONS_GAM"
    echo "\t--l=$LEARNING_RATE"
    echo "\t--i2=$ITERATIONS_GA2M"
    echo "\t--task=$TASK"
    echo "\t--out=$OUTPUT"
    echo ""
}

# Default value
OUTPUT="."

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        --all)
            ALL_DATA=$VALUE
            ;;
        --train)
            TRAIN_DATA=$VALUE
            ;;
        --valid)
            VALID_DATA=$VALUE
            ;;
        --test)
            TEST_DATA=$VALUE
            ;;
        --i1)
            ITERATIONS_GAM=$VALUE
            ;;
        --l)
            LEARNING_RATE=$VALUE
            ;;
        --i2)
            ITERATIONS_GA2M=$VALUE
            ;;
        --attr)
            ATTRIBUTES=$VALUE
            ;;
        --task)
            TASK=$VALUE
            ;;
        --out)
            OUTPUT=$VALUE
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

# write output with timestamp
today=`date '+%Y_%m_%d-%H_%M_%S'`;
output_filename="$OUTPUT/mltk-output-$today.out"

echo ""
echo "1. Create binned data of all data (train + valid + test) and attribute file for binning"
java -Xmx4g -cp $MLTK mltk.core.processor.Discretizer \
-i $ALL_DATA \
-o "$ALL_DATA.binned" \
-r $ATTRIBUTES \
-t $ALL_DATA \
-m "$ATTRIBUTES.binned"

echo ""
echo "2. Create binned data for train/valid/test"
java -Xmx4g -cp $MLTK mltk.core.processor.Discretizer \
-r $ATTRIBUTES \
-d "$ATTRIBUTES.binned" \
-i $TRAIN_DATA \
-o "$TRAIN_DATA.binned"

java -Xmx4g -cp $MLTK mltk.core.processor.Discretizer \
-r $ATTRIBUTES \
-d "$ATTRIBUTES.binned" \
-i $VALID_DATA \
-o "$VALID_DATA.binned"

java -Xmx4g -cp $MLTK mltk.core.processor.Discretizer \
-r $ATTRIBUTES \
-d "$ATTRIBUTES.binned" \
-i $TEST_DATA \
-o "$TEST_DATA.binned"

echo ""
echo "3. Train GAMLearner, i.e. create shape function for each variable"
java -Xmx4g -cp $MLTK mltk.predictor.gam.GAMLearner \
-r "$ATTRIBUTES.binned" \
-t "$TRAIN_DATA.binned" \
-v "$VALID_DATA.binned" \
-m $ITERATIONS_GAM \
-l $LEARNING_RATE \
-g $TASK \
-o gam.model

echo ""
echo "4. Error rate on train/valid/test"
java -Xmx4g -cp $MLTK mltk.predictor.evaluation.Predictor \
-r "$ATTRIBUTES.binned" \
-d "$TRAIN_DATA.binned" \
-m gam.model \
-g $TASK \
-R residuals-gam.txt

java -Xmx4g -cp $MLTK mltk.predictor.evaluation.Predictor \
-r "$ATTRIBUTES.binned" \
-d "$VALID_DATA.binned" \
-m gam.model \
-g $TASK 

java -Xmx4g -cp $MLTK mltk.predictor.evaluation.Predictor \
-r "$ATTRIBUTES.binned" \
-d "$TEST_DATA.binned" \
-m gam.model \
-g $TASK 

echo ""
echo "5. Determine interacting pairs with FAST"
java -Xmx4g -cp $MLTK mltk.predictor.gam.interaction.FAST \
-r "$ATTRIBUTES.binned" \
-d "$TRAIN_DATA.binned" \
-R residuals-gam.txt \
-o pairs.txt

echo ""
echo "6. Train GA2MLearner, i.e. create shape function for pairs of variables"
java -Xmx4g -cp $MLTK mltk.predictor.gam.GA2MLearner \
-r "$ATTRIBUTES.binned" \
-t "$TRAIN_DATA.binned" \
-v "$VALID_DATA.binned" \
-I pairs.txt \
-m $ITERATIONS_GA2M \
-i gam.model \
-o ga2m.model

echo ""
echo "7. Error rate on train/valid/test"
java -Xmx4g -cp $MLTK mltk.predictor.evaluation.Predictor \
-r "$ATTRIBUTES.binned" \
-d "$TRAIN_DATA.binned" \
-m ga2m.model \
-g $TASK  \
-R residuals-ga2m.txt

java -Xmx4g -cp $MLTK mltk.predictor.evaluation.Predictor \
-r "$ATTRIBUTES.binned" \
-d "$VALID_DATA.binned" \
-m ga2m.model \
-g $TASK  \
-R residuals-ga2m.txt

java -Xmx4g -cp $MLTK mltk.predictor.evaluation.Predictor \
-r "$ATTRIBUTES.binned" \
-d "$TEST_DATA.binned" \
-m ga2m.model \
-g $TASK  \
-R residuals-ga2m.txt

echo ""
echo "8. Determine diagnostics on train data"
java -Xmx4g -cp $MLTK  mltk.predictor.gam.tool.Diagnostics \
-r "$ATTRIBUTES.binned" \
-d "$TRAIN_DATA.binned" \
-i ga2m.model \
-o diagnostics.txt 

 #&>> "${output_filename}"