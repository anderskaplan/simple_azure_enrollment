# generate a private key and certificate request for a device
openssl req -new -config create_device_cert_req.cfg -newkey rsa -keyout device_private_key.pem -out device_cert_req.pem
