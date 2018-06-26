#!/usr/bin/env bash
#
# Copyright (c) 2017 Jeromy Johnson
# MIT Licensed; see the LICENSE file in this repository.
#

test_description="Test out the urlstore functionality"

. lib/test-lib.sh

test_init_ipfs

test_expect_success "enable urlstore" '
  ipfs config --json Experimental.UrlstoreEnabled true
'

test_expect_success "create some random files" '
  random 2222     7 > file1 &&
  random 500000   7 > file2 &&
  random 50000000 7 > file3
'

test_expect_success "add files using trickle dag format without raw leaves" '
  HASH1a=$(ipfs add -q --trickle --raw-leaves=false file1) &&
  HASH2a=$(ipfs add -q --trickle --raw-leaves=false file2) &&
  HASH3a=$(ipfs add -q --trickle --raw-leaves=false file3)
'
test_launch_ipfs_daemon --offline

test_expect_success "make sure files can be retrived via the gateway" '
  curl http://127.0.0.1:$GWAY_PORT/ipfs/$HASH1a -o file1.actual &&
  test_cmp file1 file1.actual &&
  curl http://127.0.0.1:$GWAY_PORT/ipfs/$HASH2a -o file2.actual &&
  test_cmp file2 file2.actual &&
  curl http://127.0.0.1:$GWAY_PORT/ipfs/$HASH3a -o file3.actual &&
  test_cmp file3 file3.actual 
'

test_expect_success "add files using gateway address via url store" '
  HASH1=$(ipfs urlstore add http://127.0.0.1:$GWAY_PORT/ipfs/$HASH1a) &&
  HASH2=$(ipfs urlstore add http://127.0.0.1:$GWAY_PORT/ipfs/$HASH2a) &&
  ipfs pin add $HASH1 $HASH2
'

test_expect_success "make sure hashes are different" '
  echo $HASH1a $HASH1 ## FIXME
  echo $HASH2a $HASH2 ## FIXME
'

test_expect_success "get files via urlstore" '
  ipfs get $HASH1 -o file1.actual &&
  test_cmp file1 file1.actual &&
  ipfs get $HASH2 -o file2.actual &&
  test_cmp file2 file2.actual
'

cat <<EOF | sort > ls_expect
zb2rhX1q5oFFzEkPNsTe1Y8osUdFqSQGjUWRZsqC9fbY6WVSk  262144 http://127.0.0.1:$GWAY_PORT/ipfs/QmUow2T4P69nEsqTQDZCt8yg9CPS8GFmpuDAr5YtsPhTdM 0
zb2rhYbKFn1UWGHXaAitcdVTkDGTykX8RFpGWzRFuLpoe9VE4  237856 http://127.0.0.1:$GWAY_PORT/ipfs/QmUow2T4P69nEsqTQDZCt8yg9CPS8GFmpuDAr5YtsPhTdM 262144
zb2rhjddJ5DNzBrFu8G6CP1ApY25BukwCeskXHzN1H18CiVVZ    2222 http://127.0.0.1:$GWAY_PORT/ipfs/QmcHm3BL2cXuQ6rJdKQgPrmT9suqGkfy2KzH3MkXPEBXU6 0
EOF

test_expect_success "ipfs filestore ls works with urls" '
  ipfs filestore ls | sort > ls_actual &&
  test_cmp ls_expect ls_actual
'

cat <<EOF | sort > verify_expect
ok      zb2rhX1q5oFFzEkPNsTe1Y8osUdFqSQGjUWRZsqC9fbY6WVSk  262144 http://127.0.0.1:$GWAY_PORT/ipfs/QmUow2T4P69nEsqTQDZCt8yg9CPS8GFmpuDAr5YtsPhTdM 0
ok      zb2rhYbKFn1UWGHXaAitcdVTkDGTykX8RFpGWzRFuLpoe9VE4  237856 http://127.0.0.1:$GWAY_PORT/ipfs/QmUow2T4P69nEsqTQDZCt8yg9CPS8GFmpuDAr5YtsPhTdM 262144
ok      zb2rhjddJ5DNzBrFu8G6CP1ApY25BukwCeskXHzN1H18CiVVZ    2222 http://127.0.0.1:$GWAY_PORT/ipfs/QmcHm3BL2cXuQ6rJdKQgPrmT9suqGkfy2KzH3MkXPEBXU6 0
EOF

test_expect_success "ipfs filestore verify works with urls" '
  ipfs filestore verify | sort > verify_actual &&
  test_cmp verify_expect verify_actual
'

test_expect_success "remove original hashes from local gateway" '
  ipfs pin rm $HASH1a $HASH2a &&
  ipfs repo gc > /dev/null
'

test_expect_success "gatway no longer has files" '
  test_must_fail curl -f http://127.0.0.1:$GWAY_PORT/ipfs/$HASH1a -o file1.actual
  test_must_fail curl -f http://127.0.0.1:$GWAY_PORT/ipfs/$HASH2a -o file2.actual
'

cat <<EOF | sort > verify_expect_2
error   zb2rhX1q5oFFzEkPNsTe1Y8osUdFqSQGjUWRZsqC9fbY6WVSk  262144 http://127.0.0.1:$GWAY_PORT/ipfs/QmUow2T4P69nEsqTQDZCt8yg9CPS8GFmpuDAr5YtsPhTdM 0
error   zb2rhYbKFn1UWGHXaAitcdVTkDGTykX8RFpGWzRFuLpoe9VE4  237856 http://127.0.0.1:$GWAY_PORT/ipfs/QmUow2T4P69nEsqTQDZCt8yg9CPS8GFmpuDAr5YtsPhTdM 262144
error   zb2rhjddJ5DNzBrFu8G6CP1ApY25BukwCeskXHzN1H18CiVVZ    2222 http://127.0.0.1:$GWAY_PORT/ipfs/QmcHm3BL2cXuQ6rJdKQgPrmT9suqGkfy2KzH3MkXPEBXU6 0
EOF

test_expect_success "ipfs filestore verify is correct" '
  ipfs filestore verify | sort > verify_actual_2 &&
  test_cmp verify_expect_2 verify_actual_2
'

test_expect_success "files can not be retrieved via the urlstore" '
  test_must_fail ipfs get $HASH1 &&
  test_must_fail ipfs get $HASH2
'

test_expect_success "add large file using gateway address via url store" '
  HASH3=$(ipfs urlstore add http://127.0.0.1:$GWAY_PORT/ipfs/$HASH3a)
'

test_expect_success "get large file via urlstore" '
  ipfs get $HASH3 -o file3.actual &&
  test_cmp file3 file3.actual
'

test_kill_ipfs_daemon

test_done
