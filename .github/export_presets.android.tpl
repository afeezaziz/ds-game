[preset.0]

name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="../../build/__GAME__.aab"

[preset.0.options]

custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=true
gradle_build/export_format=1
gradle_build/min_sdk=""
gradle_build/target_sdk=""
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
version/code=1
version/name="1.0"
package/unique_name="com.dreamstudio.__GAME__"
package/name="__GAME__"
keystore/debug=""
keystore/debug_user=""
keystore/debug_password=""
keystore/release="__KEYSTORE__"
keystore/release_user="__KS_USER__"
keystore/release_password="__KS_PASS__"
screen/immersive_mode=true
