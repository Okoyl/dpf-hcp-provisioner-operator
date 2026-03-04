/*
Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package util

import (
	"fmt"
	"net/url"
	"strconv"
)

// OctalToDecimal converts an integer interpreted as octal to its decimal equivalent
func OctalToDecimal(octal int) int {
	octalStr := fmt.Sprintf("%d", octal)
	decimal, err := strconv.ParseInt(octalStr, 8, 64)
	if err != nil {
		// If parsing fails, return 0
		return 0
	}
	return int(decimal)
}

// URLEncode creates a data URI with RFC 2397 encoding
func URLEncode(s string) string {
	return "data:text/plain," + url.QueryEscape(s)
}
