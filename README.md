Perl script to make management of alt coin wallets easier.

Support for performing limited actions of pre-configured coins.

Run on either all or coins passed in argument. Execute examples listed below.

# Script Arguments

__conf__: Location of JSON Wallet conf file. (Defaults to ~/wallet_conf.json)

__actions__: Comma separated list of actions (See below)

__wallets__: Comma separated list of wallets (Must be defined in conf file)

__backup_dir__: Directory to backup wallets to (Defaults to ~/Dropbox)

__make_dir__: Directory to build clients when making. (Defaults to pwd)

__quiet__: Suppress output (Default False)

__force__: Send a -9 to the kill client command (Default False)

__disable_prompt__: By default, the script prompts to continue in the event no wallets 
are specified. This is help to mitigate accidental actions, but can 
be disabled if needed. (Default False)

# Script Actions:
__Launch__ - launches coin Qt clients

__Kill__ - Kill Qt client (See optional force parameter) 

__Restart__ - Restart Qt client (Performs kill, launch)

__Backup__ - Backups wallet files into hierarchical date format to given directory (Dropbox Recommended)

__Reload__ - Kills Qt client, grabs latest backup from backup directory, launches client.

__Make__ - This is experimental, it was added to ease me deploying this on other computers, it
likely won't work for anyone else, but it can be tried. 

# Wallet Config Options:

__name__: The name of the Wallet directory

__dir__: The full path of Wallet src directory

__url__: The Github Src URL, required for "make"

__qt_exe__: Optional name of built executable if different

__wallet_file__: Location to wallet file if different

__pre_make__: Optional bash commands to run before qmake/make if
using "make" action

# Examples

__Launch all wallets - Skip prompt on all coin modification__

./wallet_manager.pl --actions="launch" --disable-prompt

__Kills all wallets - Suppress output__

./wallet_manager.pl --actions="kill" --quiet

__Force Kills DopeCoin client__

./wallet_manager.pl --actions="kill" --wallets="DopeCoin" --force 

__Restart dogecoin, litecoin client__

./wallet_manager.pl --actions="restart" --wallets="dogecoin, litecoin"

__Backup then kill all wallets and clients__

./wallet_manager.pl --actions="backup, kill" --backup_dir="/home/user/Dropbox/"

__Reload (Update wallet from backup) all clients__

./wallet_manager.pl --actions="reload"

__Make all clients in conf file__

./wallet_manager.pl --actions="make" --make_dir="/home/user/Wallets"
