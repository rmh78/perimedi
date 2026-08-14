# Point CLI tools at the full Xcode.app (this Mac's xcode-select still
# targets Command Line Tools; switching that path needs sudo).
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
