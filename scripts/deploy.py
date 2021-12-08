from brownie import PandasMatrix, accounts, config
#from scripts.helpful_scripts import get_account

def main():
    account = accounts[1] #accounts.add(config['wallets']['from_key']) or
    contract = PandasMatrix.deploy(0xd55A01eFcF6Bd17A4D2b660260D83478118f33c4, {'from': account}) #0xBCD9A216ba2c6346615B637Bb3A9CaC5117618e2

    contract.registrationExt(0xd55A01eFcF6Bd17A4D2b660260D83478118f33c4, {'from': account})

if __name__ == '__main__':
    main()




