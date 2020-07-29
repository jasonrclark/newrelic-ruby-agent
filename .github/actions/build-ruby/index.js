const os = require('os')
const fs = require('fs')
const path = require('path')

const core = require('@actions/core')
const github = require('@actions/github')
const exec = require('@actions/exec')


function chomp(raw_text) {
  return raw_text.replace(/(\n|\r)+$/, '')
}

async function execute(command) {
 try {
   let outputStr = ''

   const options = {}
   options.listeners = {
     stdout: (data) => { outputStr += data.toString() },
     stderr: (data) => { console.log(data.toString()) }
   }

   await exec.exec(command, [], options)

   return chomp(outputStr);

 } catch (error) {
   console.error(error.toString())
 }
}

async function installSystemDependencies() {
  core.startGroup(`Installing system dependencies`)

  const dependencyList = 'libyaml-dev libgdbm-dev libreadline-dev libncurses5-dev zlib1g-dev libffi-dev'

  console.log(`installing system dependencies ${dependencyList}`)

  await exec.exec('sudo apt-get update')
  await exec.exec(`sudo apt-get install -y --no-install-recommends ${dependencyList}`)

  core.endGroup()
}

async function installRubyBuild(rubyVersion) {
  core.startGroup(`Installing ruby-build`)

  const buildDir = `${process.env.HOME}/ruby-build`
  var repoPath

  // Rubies 2.0 ... 2.3 (these need OpenSSL 1.0 and eregon provides it for us)
  if (rubyVersion.match(/^2\.[0123]/)) {
    console.log('cloning eregon/ruby-build')
    repoPath = '--branch ruby23-openssl-linux https://github.com/eregon/ruby-build.git'

  // all the other Rubies
  } else {
    console.log('cloning rbenv/ruby-build')
    repoPath = 'https://github.com/rbenv/ruby-build.git'
  }

  await exec.exec(`git clone ${repoPath} ${buildDir}`)
  await exec.exec(`sudo ${buildDir}/install.sh && ruby-build --definitions`)

  core.endGroup()
}

function setupBuildEnvironment() {
  core.exportVariable('RUBY_CONFIGURE_OPTS', '--enable-shared --disable-install-doc')
  // https://github.com/actions/virtual-environments/issues/267
  core.exportVariable('CPPFLAGS', '-DENABLE_PATH_CHECK=0')
}

function addRubyToPath(rubyVersion) {
  core.addPath(`${process.env.HOME}/.rubies/ruby-${rubyVersion}/bin`)
}

async function buildRuby(rubyVersion) {
  core.startGroup(`Build Ruby ${rubyVersion}`)
  await exec.exec(`ruby-build --verbose ${rubyVersion} ${process.env.HOME}/.rubies/ruby-${rubyVersion}`) 
  core.endGroup()
}

async function upgradeRubyGems(rubyVersion) {
  core.startGroup(`Upgrade RubyGems`)

  await execute('gem --version').then(res => { gemVersionStr = res; });

  console.log(`Current RubyGems is "${gemVersionStr}"`)

  if (parseFloat(rubyVersion) < 2.7) {

    if (parseFloat(gemVersionStr) < 3.0) {
      console.log(`Ruby < 2.7, upgrading RubyGems from ${gemVersionStr}`)

      await exec.exec('gem', ['update', '--system', '3.0.6', '--force']).then(res => { exitCode = res });
      if (exitCode != 0) {
        await exec.exec('gem', ['install', 'rubygems-update', '-v', '<3'])
        await exec.exec('update_rubygems')
      };
      
    }
    else {
      console.log(`Ruby < 2.7, but RubyGems already at ${gemVersionStr}`)
    }
  } 

  else {
    console.log(`Ruby >= 2.7, keeping RubyGems at ${gemVersionStr}`)
  }

  await execute('which gem').then(res => { console.log("which gem: " + res) });
  await execute('gem --version').then(res => { console.log("New RubyGems is: " + res) });

  core.endGroup()
}

async function installBundler(rubyVersion) {
  core.startGroup(`Install bundler`)

  const bundlePath = `${process.env.HOME}/.rubies/ruby-${rubyVersion}/bin`

  if (!fs.existsSync(`${bundlePath}/bundle`)) {
    await exec.exec('sudo', ['gem', 'install', 'bundler', '-v', '~> 1', '--no-document', '--bindir', bundlePath])
  }

  core.endGroup()
}

async function buildThatRuby() {
  const rubyVersion = core.getInput('ruby-version')

  try {
    setupBuildEnvironment()
    addRubyToPath(rubyVersion)

    await installRubyBuild(rubyVersion)
    await installSystemDependencies()
    await buildRuby(rubyVersion)
    await upgradeRubyGems(rubyVersion)
    await installBundler(rubyVersion)

  }
  catch (error) {
    core.setFailed(error.message)
  }
}

buildThatRuby()
