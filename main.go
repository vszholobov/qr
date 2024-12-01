package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image/png"
	"os"
	"strings"

	"github.com/boombuler/barcode"
	"github.com/boombuler/barcode/qr"
	"github.com/google/uuid"
)

type Request struct {
	HttpMethod      string `json:"httpMethod"`
	Body            string `json:"body"`
	IsBase64Encoded bool   `json:"isBase64Encoded"`
}

type RequestBody struct {
	Link   string `json:"link"`
	QrSize int    `json:"qrSize"`
}

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
	requestBody := &RequestBody{}
	json.Unmarshal([]byte(request.Body), &requestBody)

	link := requestBody.Link
	if requestBody.QrSize < 1 || requestBody.QrSize > 6 {
		return makeResponse(400, nil, "Wrong qrSize"), nil
	}
	qrSize := requestBody.QrSize * 100
	if len(strings.TrimSpace(link)) == 0 {
		return makeResponse(400, nil, "Link is empty"), nil
	}

	qrFilename := fmt.Sprintf("%s/%s.png", os.Getenv("QR_FILE_PATH"), uuid.NewString())
	println(qrFilename)
	file, err := qrCodeGen(link, qrFilename, qrSize)
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
	os.Remove(qrFilename)
	headers := map[string]string{"Content-Type": "image/png"}
	return makeResponse(200, headers, base64Encoded), nil
}

func qrCodeGen(content string, filename string, qrSize int) (*os.File, error) {
	qrCode, _ := qr.Encode(content, qr.M, qr.Auto)
	qrCode, _ = barcode.Scale(qrCode, qrSize, qrSize)
	file, err := os.Create(filename)
	if err != nil {
		return file, err
	}
	png.Encode(file, qrCode)
	err = file.Close()
	if err != nil {
		return file, err
	}
	file, err = os.Open(filename)
	return file, err
}
