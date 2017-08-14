// Copyright 2017 Google Inc. All Rights Reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//     http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"io/ioutil"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"
)

type vaultToken struct {
	token string
	path  string
	mu    *sync.RWMutex
}

func newVaultToken() (*vaultToken, error) {
	vt := &vaultToken{
		path: "secrets/vault_token",
		mu:   &sync.RWMutex{},
	}
	err := vt.updateTokenFromFile()
	if err != nil {
		return nil, err
	}

	return vt, nil
}

func (vt *vaultToken) updateTokenFromFile() error {
	data, err := ioutil.ReadFile(vt.path)
	if err != nil {
		return err
	}

	vt.mu.Lock()
	vt.token = string(data)
	vt.mu.Unlock()

	return nil
}

func (vt *vaultToken) getToken() string {
	vt.mu.RLock()
	defer vt.mu.RUnlock()
	return vt.token
}

func main() {
	log.Println("starting token-printer service...")
	done := make(chan struct{})

	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, syscall.SIGHUP, syscall.SIGINT, syscall.SIGTERM)

	var wg sync.WaitGroup
	var vt *vaultToken
	var err error

	for {
		vt, err = newVaultToken()
		if err != nil {
			log.Printf("error getting initial vault token: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}
		break
	}

	go func() {
		wg.Add(1)
		for {
			select {
			case <-time.After(1 * time.Second):
				log.Printf("current token value: %s", vt.getToken())
			case <-done:
				wg.Done()
				return
			}
		}
	}()

	for {
		s := <-signalChan
		switch s {
		case syscall.SIGHUP:
			log.Println("reloading vault token...")
			vt.updateTokenFromFile()
		case syscall.SIGINT, syscall.SIGTERM:
			log.Printf("shutdown signal received, exiting...")
			close(done)
			wg.Wait()
			os.Exit(0)
		}
	}
}
