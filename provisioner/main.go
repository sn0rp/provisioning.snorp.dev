package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"text/template"
)

const (
	templateDir = "/home/sites/provisioning.snorp.dev/templates"
	listenAddr  = ":8080"
)

type Params struct {
	Hostname string
	Username string
	SSHKey   string
}

func configHandler(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/config/")
	path = strings.Trim(path, "/")

	if path == "" {
		http.Error(w, "usage: /config/{distro}", http.StatusBadRequest)
		return
	}

	var distro string
	var serveMetaData bool

	if strings.HasSuffix(path, "/user-data") {
		distro = strings.TrimSuffix(path, "/user-data")
		serveMetaData = false
	} else if strings.HasSuffix(path, "/meta-data") {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Write([]byte("instance-id: openclaw\nlocal-hostname: openclaw\n"))
		return
	} else {
		distro = path
		serveMetaData = false
	}

	_ = serveMetaData

	distro = filepath.Base(distro)

	tmplPath := filepath.Join(templateDir, distro)
	if _, err := os.Stat(tmplPath); os.IsNotExist(err) {
		http.Error(w, "unknown distro: "+distro, http.StatusNotFound)
		return
	}

	tmpl, err := template.ParseFiles(tmplPath)
	if err != nil {
		http.Error(w, "template parse error: "+err.Error(), http.StatusInternalServerError)
		log.Printf("template parse error for %s: %v", distro, err)
		return
	}

	params := Params{
		Hostname: r.URL.Query().Get("hostname"),
		Username: r.URL.Query().Get("username"),
		SSHKey:   r.URL.Query().Get("sshkey"),
	}
	if params.Hostname == "" {
		params.Hostname = "homelab"
	}
	if params.Username == "" {
		params.Username = "snorp"
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	if err := tmpl.Execute(w, params); err != nil {
		log.Printf("template execute error for %s: %v", distro, err)
	}
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/config/", configHandler)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	log.Printf("provisioner listening on %s, templates at %s", listenAddr, templateDir)
	if err := http.ListenAndServe(listenAddr, mux); err != nil {
		log.Fatal(err)
	}
}
