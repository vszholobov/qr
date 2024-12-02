yc config profile activate qr-coder
export YC_TOKEN=$(yc iam create-token) # yandex cloud access token
zip function.zip main.go go.mod go.sum
