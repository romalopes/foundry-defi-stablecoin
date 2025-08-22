-include .env

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops@0.2.2 && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && forge install foundry-rs/forge-std@v1.8.2

github:
	@echo "Pushing to GitHub..."
	git add .
	git commit -m "Update Makefile and scripts"
	git push origin main

# Update Dependencies 
update:; forge update

format :; forge fmt
lint: ## Lint the code
	@echo "Linting the code..."
	forge fmt --check --diff
build: ## Build the project
	@echo "Building the project..."
	forge build
test-local: ## Run tests
	@echo "Running tests..."
	forge test ## --match-contract FundMeTest -vvv	
test-metamask: ## Run tests with Metamask fork
	@echo "Running tests with Metamask fork..."
	forge test --rpc-url $(METAMASK_RPC_URL) -vvv ## --match-contract FundMeTest 
test-alchemy: ## Run tests with Alchemy fork
	@echo "Running tests with Alchemy fork..."
	forge test --fork-url $(ALCHEMY_RPC_URL) -vvv ## --match-contract FundMeTest 
test-quicknode: ## Run tests with QuickNode fork
	@echo "Running tests with QuickNode fork..."
	forge test --fork-url $(QUICKNODE_RPC_URL) -vvv ## --match-contract FundMeTest
snapshot :; forge snapshot	
cast-storage: ## Cast storage
	@echo "Casting storage..."
	cast storage 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 1
deploy-anvil: ## Deploy to Anvil
	@echo "Deploying to Anvil..."
	forge script script/DeployFundMe.s.sol --rpc-url $(LOCAL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast
deploy-alchemy-account-1: ## Deploy to Alchemy
	@echo "Deploying to Alchemy..."
	forge script script/DeployFundMe.s.sol --rpc-url $(ALCHEMY_RPC_URL) --private-key $(ACCOUNT_1_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)
deploy-quicknode-chrome-account-1: ## Deploy to QuickNode
	@echo "Deploying to QuickNode..."
	forge script script/DeployFundMe.s.sol --rpc-url $(QUICKNODE_RPC_URL) --private-key $(CHROME_ACCOUNT_1_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)
deploy-metamask-account-2: ## Deploy to Metamask
	@echo "Deploying to Metamask..."
	forge script script/DeployFundMe.s.sol --rpc-url $(METAMASK_RPC_URL) --private-key $(ACCOUNT_2_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(ANVIL_PRIVATE_KEY) --broadcast

# For deploying Interactions.s.sol:FundFundMe as well as for Interactions.s.sol:WithdrawFundMe we have to include a sender's address `--sender <ADDRESS>`
SENDER_ADDRESS := 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
 
fund:
	@forge script script/Interactions.s.sol:FundFundMe --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)

withdraw:
	@forge script script/Interactions.s.sol:WithdrawFundMe --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)