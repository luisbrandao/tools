<?php
  // Esse script lista os repos da organização $org. Para usar, coloque o seu usuario em
  // $user e gere um token de acesso do github e o coloque em $token
  // Um exemplo de uso pratico desse script:
  // for line in $(php ~/bin/github-repolist.php); do git clone ${line}; done


  // for example your user
  $user = 'user';
  $org = 'organization';

  // A token that you could generate from your own github
  // go here https://github.com/settings/applications and create a token
  // then replace the next string
  $token = 'user-token';

  // We generate the url for curl
  $curl_url = 'https://api.github.com/orgs/' . $org . '/repos' . '?per_page=1000' ;

  // We generate the header part for the token
  $curl_token_auth = 'Authorization: token ' . $token;

  // We make the actuall curl initialization
  $ch = curl_init($curl_url);

  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);

  // We set the right headers: any user agent type, and then the custom token header part that we generated
  curl_setopt($ch, CURLOPT_HTTPHEADER, array('User-Agent: Awesome-Octocat-App', $curl_token_auth));

  // We execute the curl
  $output = curl_exec($ch);

  // And we make sure we close the curl
  curl_close($ch);

  // Then we decode the output and we could do whatever we want with it
  $output = json_decode($output);

  if (!empty($output)) {

    //var_dump($output);

    // now you could just foreach the repos and show them
    foreach ($output as $repo) {
      echo ($repo->ssh_url."\n");
    }
  }
?>
