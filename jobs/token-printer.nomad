job "token-printer" {
  datacenters = ["dc1"]

  group "example" {
    task "token-printer" {
      artifact {
        source = "https://storage.googleapis.com/hashistack/token-printer/token-printer"
        options {
          checksum = "sha256:9ca8b8d3550a18d00dbe2cc0494378832094f4948a0bccbd01719945683d339a"
        }
      }

      driver = "exec"
      config {
        command = "token-printer"
      }

      vault {
        policies = ["default"]

        change_mode = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}
