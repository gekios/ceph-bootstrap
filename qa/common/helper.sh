# This file is part of the ceph-bootstrap integration test suite

set -e

#
# helper functions (not to be called directly from test scripts)
#

function _run_test_script_on_node {
    local TESTSCRIPT=$1 # on success, TESTSCRIPT must output the exact string
                        # "Result: OK" on a line by itself, otherwise it will
                        # be considered to have failed
    local TESTNODE=$2
    local ASUSER=$3
    salt-cp $TESTNODE $TESTSCRIPT $TESTSCRIPT 2>/dev/null
    local LOGFILE=/tmp/test_script.log
    local STDERR_LOGFILE=/tmp/test_script_stderr.log
    local stage_status=
    if [ -z "$ASUSER" -o "x$ASUSER" = "xroot" ] ; then
      salt $TESTNODE cmd.run "sh $TESTSCRIPT" 2>$STDERR_LOGFILE | tee $LOGFILE
      stage_status="${PIPESTATUS[0]}"
    else
      salt $TESTNODE cmd.run "sudo su $ASUSER -c \"bash $TESTSCRIPT\"" 2>$STDERR_LOGFILE | tee $LOGFILE
      stage_status="${PIPESTATUS[0]}"
    fi
    local RESULT=$(grep -o -P '(?<=Result: )(OK)$' $LOGFILE) # since the script
                                  # is run by salt, the output appears indented
    test "x$RESULT" = "xOK" && return
    echo "The test script that ran on $TESTNODE failed. The stderr output was as follows:"
    cat $STDERR_LOGFILE
    exit 1
}

function _grace_period {
    local SECONDS=$1
    echo "${SECONDS}-second grace period"
    sleep $SECONDS
}

function _root_fs_is_btrfs {
    stat -f / | grep -q 'Type: btrfs'
}

function _ping_minions_until_all_respond {
    local RESPONDING=""
    for i in {1..20} ; do
        sleep 10
        RESPONDING=$(salt '*' test.ping 2>/dev/null | grep True 2>/dev/null | wc --lines)
        echo "Of $TOTAL_NODES total minions, $RESPONDING are responding"
        test "$TOTAL_NODES" -eq "$RESPONDING" && break
    done
}

function ceph_cluster_running {
    ceph status >/dev/null 2>&1
}

