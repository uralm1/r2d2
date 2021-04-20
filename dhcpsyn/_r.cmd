@rem verify = SSL_VERIFY_PEER (0x01) & SSL_VERIFY_FAIL_IF_NO_PEER_CERT (0x02)

@script/dhcpsyn daemon -l "https://*:2274?cert=plksrv1-cert.pem&key=plksrv1-key.pem&ca=ca.pem&verify=0x03"
@rem script/dhcpsyn threaded -l "https://*:2274?cert=plksrv1-cert.pem&key=plksrv1-key.pem&ca=ca.pem&verify=0x03" -P threaded.pid
