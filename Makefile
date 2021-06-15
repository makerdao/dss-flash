all             :; dapp --use solc:0.6.12 build
clean           :; dapp clean
test            :; dapp --use solc:0.6.12 test -v
test-match      :; dapp --use solc:0.6.12 test -v --match=$(match)
flatten         :; hevm flatten --source-file=src/flash.sol > out/flash-flattened.sol
deploy-mainnet  :; make && dapp create DssFlash 0x9759A6Ac90977b93B58547b4A71c78317f391A28 0xA950524441892A31ebddF91d3cEEFa04Bf454466
deploy-kovan    :; make && dapp create DssFlash 0x5AA71a3ae1C0bd6ac27A1f28e1415fFFB6F15B8c 0x0F4Cbe6CBA918b7488C26E29d9ECd7368F38EA3b
