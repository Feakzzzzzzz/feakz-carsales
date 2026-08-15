fx_version 'cerulean'
game 'gta5'

author 'Feakz'
description 'Physical player-to-player vehicle sale signs'
version '1.1.3'

lua54 'yes'
ui_page 'html/sign.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/config_defaults.lua',
    'shared/utils.lua',
    'shared/vehicle_properties.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

files {
    'html/sign.html',
    'html/sign.css',
    'html/sign.js',
    'install/car_sale_sign.png'
}

dependencies {
    'ox_lib',
    'ox_target',
    'oxmysql'
}

server_exports {
    'IsVehicleForSale',
    'GetListingByPlate',
    'GetListingByNetId'
}
