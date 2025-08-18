import os
import json
import time
from web3 import Web3
from solcx import compile_files, install_solc, set_solc_version

def generate_standard_json_input(contract_path, source_code):
    """
    یک فایل با فرمت Standard-JSON-Input برای وریفای کردن قرارداد در اکسپلوررها تولید می‌کند.
    """
    return {
        "language": "Solidity",
        "sources": {
            contract_path: {
                "content": source_code
            }
        },
        "settings": {
            "optimizer": {
                "enabled": False,
                "runs": 200
            },
            "outputSelection": {
                "*": {
                    "*": [
                        "abi",
                        "evm.bytecode",
                        "evm.deployedBytecode",
                        "evm.methodIdentifiers",
                        "metadata"
                    ]
                }
            },
            "metadata": {
                "useLiteralContent": True
            },
            "libraries": {}
        }
    }

def wait_for_receipt(w3, tx_hash, timeout=240):
    """منتظر تایید تراکنش می‌ماند."""
    print(f"Waiting for transaction receipt for {tx_hash.hex()}...")
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=timeout)
    status = "Success" if receipt.status == 1 else "Failed"
    print(f"Transaction {tx_hash.hex()} confirmed. Status: {status}")
    if receipt.status == 0:
        raise Exception(f"Transaction failed! Check explorer for details: {tx_hash.hex()}")
    return receipt

def deploy():
    # ۱. خواندن متغیرهای محیطی
    private_key = os.environ.get("PRIVATE_KEY")
    rpc_url = os.environ.get("RPC_URL")
    chain_id = int(os.environ.get("CHAIN_ID"))
    network_name = os.environ.get("NETWORK_NAME")
    explorer_url = os.environ.get("EXPLORER_URL", "")

    if not all([private_key, rpc_url, chain_id, network_name]):
        raise ValueError("PRIVATE_KEY, RPC_URL, CHAIN_ID, and NETWORK_NAME must be set.")

    # ۲. اتصال به شبکه
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    if not w3.is_connected():
        raise ConnectionError(f"Failed to connect to RPC_URL: {rpc_url}")
    account = w3.eth.account.from_key(private_key)
    print(f"Deploying to '{network_name}' (Chain ID: {chain_id}) with account: {account.address}")

    # ۳. نصب و تنظیم کامپایلر
    solc_version = "0.8.20"
    install_solc(solc_version)
    set_solc_version(solc_version)

    # ۴. کامپایل قراردادها
    contract_paths = [
        "contracts/YazdParadiseNFT.sol",
        "contracts/ParsToken.sol",
        "contracts/MainContract.sol",
        "contracts/InteractFeeProxy.sol"
    ]
    print("Compiling contracts...")
    compiled_sol = compile_files(
        contract_paths,
        output_values=["abi", "bin"],
        import_remappings={"@openzeppelin/": "node_modules/@openzeppelin/"}
    )

    # تابع کمکی برای دیپلوی
    def deploy_contract(contract_path_name, constructor_args=[]):
        contract_name = contract_path_name.split(':')[-1]
        print(f"\nDeploying {contract_name}...")
        interface = compiled_sol[contract_path_name]
        Contract = w3.eth.contract(abi=interface['abi'], bytecode=interface['bin'])
        
        tx = Contract.constructor(*constructor_args).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address)
            # Gas و GasPrice به صورت خودکار توسط web3 تخمین زده می‌شوند
        })
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        receipt = wait_for_receipt(w3, tx_hash)
        
        contract_address = receipt.contractAddress
        print(f"-> {contract_name} deployed at: {contract_address}")
        if explorer_url:
            print(f"   Explorer link: {explorer_url}/address/{contract_address}")
        time.sleep(10)
        return w3.eth.contract(address=contract_address, abi=interface['abi'])

    # ۵. دیپلوی قراردادها
    yazd_nft_contract = deploy_contract("contracts/YazdParadiseNFT.sol:YazdParadiseNFT", [account.address])
    pars_token_contract = deploy_contract("contracts/ParsToken.sol:ParsToken", [account.address])
    main_contract = deploy_contract("contracts/MainContract.sol:MainContract", [yazd_nft_contract.address, pars_token_contract.address, account.address])
    proxy_contract = deploy_contract("contracts/InteractFeeProxy.sol:InteractFeeProxy", [main_contract.address])

    # ========== بخش اصلاح شده ==========
    # ۶. انتقال مالکیت‌ها به روش صحیح
    print("\nTransferring ownerships...")

    # تابع کمکی برای ارسال تراکنش‌های معمولی
    def send_tx(tx_function):
        tx = tx_function.build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address)
        })
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        wait_for_receipt(w3, tx_hash)
        time.sleep(10)

    print("-> Preparing to transfer YazdParadiseNFT ownership...")
    send_tx(yazd_nft_contract.functions.transferOwnership(main_contract.address))
    print("-> YazdParadiseNFT ownership transferred to MainContract.")

    print("-> Preparing to transfer ParsToken ownership...")
    send_tx(pars_token_contract.functions.transferOwnership(main_contract.address))
    print("-> ParsToken ownership transferred to MainContract.")

    print("-> Preparing to transfer MainContract ownership...")
    send_tx(main_contract.functions.transferOwnership(proxy_contract.address))
    print("-> MainContract ownership transferred to InteractFeeProxy.")
    # ==================================

    # ۷. ذخیره خروجی
    deployment_output_filename = f"deployment_output_{network_name}.json"
    deployment_info = {
        f"YazdParadiseNFT_on_{network_name}": {"address": yazd_nft_contract.address, "abi": compiled_sol['contracts/YazdParadiseNFT.sol:YazdParadiseNFT']['abi']},
        f"ParsToken_on_{network_name}": {"address": pars_token_contract.address, "abi": compiled_sol['contracts/ParsToken.sol:ParsToken']['abi']},
        f"MainContract_on_{network_name}": {"address": main_contract.address, "abi": compiled_sol['contracts/MainContract.sol:MainContract']['abi']},
        f"InteractFeeProxy_on_{network_name}": {"address": proxy_contract.address, "abi": compiled_sol['contracts/InteractFeeProxy.sol:InteractFeeProxy']['abi']}
    }
    with open(deployment_output_filename, "w") as f:
        json.dump(deployment_info, f, indent=4)
    print(f"\nDeployment details saved to {deployment_output_filename}")

    # ۸. تولید فایل‌های وریفای
    print("\nGenerating files for contract verification...")
    for path in contract_paths:
        contract_name = path.split('/')[-1].split('.')[0]
        with open(path, 'r') as file:
            source_code = file.read()
        
        std_json = generate_standard_json_input(path, source_code)
        
        verification_filename = f"verification_{contract_name}_{network_name}.json"
        with open(verification_filename, 'w') as f:
            json.dump(std_json, f, indent=2)
        print(f"  -> Created {verification_filename}")

if __name__ == "__main__":
    deploy()
