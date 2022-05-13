all             :; dapp --use solc:0.6.12 build
clean           :; dapp clean
test            :; dapp --use solc:0.6.12 test -v
test-match      :; dapp --use solc:0.6.12 test -v --match=$(match)
flatten         :; hevm flatten --source-file=src/flash.sol > out/flash-flattened.sol
deploy-mainnet  :; make && dapp create DssFlash 0x9759A6Ac90977b93B58547b4A71c78317f391A28
deploy-goerli   :; make && dapp create DssFlash 0x6a60b7070befb2bfc964F646efDF70388320f4E0
