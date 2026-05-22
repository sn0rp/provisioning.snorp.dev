package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"
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
	distro := filepath.Base(r.URL.Path)
	if distro == "" || distro == "config" {
		http.Error(w, "usage: /config/{distro}?hostname=x&username=y&sshkey=z", http.StatusBadRequest)
		return
	}

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
