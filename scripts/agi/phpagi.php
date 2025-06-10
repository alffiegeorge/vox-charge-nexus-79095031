
<?php
// Simple PHPAgi wrapper for Asterisk AGI scripts

class AGI {
    private $stdin;
    private $stdout;
    private $stderr;
    private $agi_vars = array();
    
    public function __construct() {
        $this->stdin = fopen('php://stdin', 'r');
        $this->stdout = fopen('php://stdout', 'w');
        $this->stderr = fopen('php://stderr', 'w');
        
        // Read AGI environment variables
        while (($line = fgets($this->stdin)) !== false) {
            $line = trim($line);
            if ($line === '') break;
            
            list($key, $value) = explode(':', $line, 2);
            $this->agi_vars[trim($key)] = trim($value);
        }
    }
    
    public function get_variable($name) {
        $this->command("GET VARIABLE $name");
        $response = $this->read_response();
        if (preg_match('/result=1 \((.+)\)/', $response, $matches)) {
            return $matches[1];
        }
        return '';
    }
    
    public function set_variable($name, $value) {
        $this->command("SET VARIABLE $name \"$value\"");
        return $this->read_response();
    }
    
    public function verbose($message, $level = 1) {
        $this->command("VERBOSE \"$message\" $level");
        return $this->read_response();
    }
    
    public function hangup() {
        $this->command("HANGUP");
        return $this->read_response();
    }
    
    private function command($cmd) {
        fwrite($this->stdout, $cmd . "\n");
        fflush($this->stdout);
    }
    
    private function read_response() {
        $response = fgets($this->stdin);
        return trim($response);
    }
    
    public function __destruct() {
        if ($this->stdin) fclose($this->stdin);
        if ($this->stdout) fclose($this->stdout);
        if ($this->stderr) fclose($this->stderr);
    }
}
?>
