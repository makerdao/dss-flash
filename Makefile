all     :; dapp --use solc:0.6.12 build
clean   :; dapp clean
test    :; dapp --use solc:0.6.12 test -v
flatten :; hevm flatten --source-file=src/flash.sol > out/flash-flattened.sol
deploy  :; dapp create DssFlash 0x9759A6Ac90977b93B58547b4A71c78317f391A28 0xA950524441892A31ebddF91d3cEEFa04Bf454466
