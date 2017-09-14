<?php
$MAXMEM = 94; // Define a porcentagem maxima de memoria alocada antes de se considerar como falha.
$LOADOFFSET = 2.5; // Define a porcentagem maxima de memoria alocada antes de se considerar como falha.
// === Calcula a Porcentagem de memoria em uso no sistema
function get_server_memory_usage(){
    $ramtotal = shell_exec('cat /proc/meminfo | grep "^MemTotal" | tr -s " " | cut -d" " -f 2');
    $ramlivre = shell_exec('cat /proc/meminfo | grep "^MemFree" | tr -s " " | cut -d" " -f 2');
    $rambuffer = shell_exec('cat /proc/meminfo | grep "^Buffers" | tr -s " " | cut -d" " -f 2');
    $ramcache = shell_exec('cat /proc/meminfo | grep "^Cached" | tr -s " " | cut -d" " -f 2');

    // Calcula a quantidade real em uso
    $ramusada = $ramtotal - ( $ramlivre + $rambuffer + $ramcache);

    // Porcentagem
    return floor($ramusada * 100 / $ramtotal);
}
// === Calcula o load do sistema
function get_server_load(){
    $load = sys_getloadavg();
    return $load[0];
}
// === Calcula o numero de nucleos do sistema
function get_server_cores(){
    $cores = shell_exec('cat /proc/cpuinfo | grep processor | wc -l');
    return $cores;
}

// === Calcula o uptime
function get_uptime() {
  //global $text;
  $fd = fopen('/proc/uptime', 'r');
  $ar_buf = split(' ', fgets($fd, 4096));
  fclose($fd);

  $sys_ticks = trim($ar_buf[0]);

  $min   = $sys_ticks / 60;
  $hours = $min / 60;
  $days  = floor($hours / 24);
  $hours = floor($hours - ($days * 24));
  $min   = floor($min - ($days * 60 * 24) - ($hours * 60));

  if ($days != 0) {
    $result = $days . " days ";
  }

  if ($hours != 0) {
    $result .= $hours . " hours ";
  }
  $result .= $min . " minutes";

  return $result;
}

// Define se a saida é via navegador ou curl
$bl = PHP_EOL;
if (strpos($_SERVER['HTTP_USER_AGENT'], 'curl' ) === false ){
  $bl = "<br/>";
}

// Exibe um sumario do status da maquina.
echo "System uptime: " . get_uptime(). $bl;
echo "Used memory: " . get_server_memory_usage() . "%" . $bl;
echo "5 min load: " . get_server_load(). $bl;
echo "Number of cores: " . get_server_cores(). $bl;

if (get_server_memory_usage() > $MAXMEM){
  //http_response_code(503);
  echo "Memory consumption too high!" . $bl;
}
if (get_server_load() > $LOADOFFSET * get_server_cores()){
  //http_response_code(503);
  echo "Load too high!" . $bl;
}
?>
