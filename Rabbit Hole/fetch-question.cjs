'use strict';
// Prints one API response to the parent process. Never writes questions to disk.
const category = process.argv[2] || '';
if (!['', '15', '20', '18', '24', '23', '21', '17'].includes(category)) {
  process.stderr.write('Unknown category');
  process.exit(1);
}
const url = new URL('https://opentdb.com/api.php');
url.search = new URLSearchParams({amount:'1', type:'multiple', encode:'url3986', ...(category ? {category} : {})});
fetch(url, {cache:'no-store', credentials:'omit', signal:AbortSignal.timeout(18000)})
  .then(async response => {
    if (!response.ok) throw new Error('Question service unavailable');
    process.stdout.write(JSON.stringify(await response.json()));
  })
  .catch(error => { process.stderr.write(error.message); process.exitCode = 1; });
