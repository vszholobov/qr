package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"image/png"
	"os"

	// barcode scale
	"github.com/boombuler/barcode"
	// Build the QRcode for the text
	"github.com/boombuler/barcode/qr"
)

type Request struct {
	HttpMethod      string `json:"httpMethod"`
	Body            string `json:"body"`
	IsBase64Encoded bool   `json:"isBase64Encoded"`
}

// Преобразуем поле body объекта RequestBody
type RequestBody struct {
	Link string `json:"link"`
}

/*type Request struct {
	Body       []byte `json:"body"`
	HttpMethod            string            `json:"httpMethod"`
	Headers               map[string]string `json:"headers"`
	QueryStringParameters map[string]string `json:"queryStringParameters"`
}*/

type Response struct {
	StatusCode int               `json:"statusCode"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
}

func makeResponse(statusCode int, headers map[string]string, body string) *Response {
	return &Response{
		StatusCode: statusCode,
		Headers:    headers,
		Body:       body,
	}
}

func Handler(ctx context.Context, request *Request) (*Response, error) {
	println(request.HttpMethod)
	println(request.IsBase64Encoded)
	// println(request.Headers["Host"])
	// println(request.QueryStringParameters["link"])
	// link := request.QueryStringParameters["link"]
	// if link == "" {
	// return makeResponse(500, nil, "Empty link query param"), nil
	// }

	requestBody := &RequestBody{}
	// Массив байтов, содержащий тело запроса, преобразуется в соответствующий объект
	json.Unmarshal([]byte(request.Body), &requestBody)

	link := requestBody.Link
	if link == "" {
		return makeResponse(400, nil, "link is empty"), nil
	}
	filename := "/function/storage/qrcodes/qrcode.png"
	file, err := qrCodeGen(link, filename)
	if err != nil {
		return makeResponse(500, nil, "Failed to create QR code file"), err
	}
	defer file.Close()

	fileInfo, err := file.Stat()
	if err != nil {
		return makeResponse(500, nil, "Failed to get file info"), err
	}
	buffer := make([]byte, fileInfo.Size())
	file.Read(buffer)
	base64Encoded := base64.StdEncoding.EncodeToString(buffer)
	os.Remove(filename)
	headers := map[string]string{"Content-Type": "image/png"}
	return makeResponse(200, headers, base64Encoded), nil
}

func qrCodeGen(content string, filename string) (*os.File, error) {
	// Create the barcode
	qrCode, _ := qr.Encode(content, qr.M, qr.Auto)

	// Scale the barcode to 200x200 pixels
	qrCode, _ = barcode.Scale(qrCode, 500, 500)

	// create the output file
	file, err := os.Create(filename)

	// encode the barcode as png
	png.Encode(file, qrCode)
	file.Close()

	file, err = os.Open(filename)

	return file, err
}
