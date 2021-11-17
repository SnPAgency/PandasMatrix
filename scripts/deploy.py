from brownie import accounts, PanadasMatrix, config, networks
from helpful_scripts import get_account

def main():
    account = get_account()#accounts.add(config['wallets']['from_key']) or accounts[0]
    PanadasMatrix.deploy(0xBCD9A216ba2c6346615B637Bb3A9CaC5117618e2, {'from': account})


if __name__ == '__main__':
    main()




