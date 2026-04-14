const p = require('path')
const fs = require('fs')
const dbPath = p.join(__dirname, '../deploys', 'address.json') // 合约地址
const configPath = p.join(__dirname, '../', 'paramConfig.json') // 参数配置
const contractTemplate = p.join(__dirname, '../deploys', 'redeployParam.json') // 合约模板

const db  = {
  read(path = dbPath) {
    return new Promise((resolve, reject) => {
      fs.readFile(path, { encoding: 'utf8' }, (err, data) => {
        if (err) return reject(err)
        resolve(JSON.parse(data.toString()))
      })
    })
  },
  write(data, path = dbPath) {
    return new Promise((resolve, reject) => {
      fs.writeFile(path, JSON
        .stringify(data, '', '\t'), (err) => {
        if (err) return reject(err)
        resolve()
      })
    })
  },
  readConfig(path = configPath) {
    return new Promise((resolve, reject) => {
      fs.readFile( path, {
        encoding: 'utf8'
      }, (err, data) => {
        if (err) return reject(err)
        resolve(JSON.parse(data.toString()))
      })
    })
  },
  readContractTemplate(path = contractTemplate) {
    return new Promise((resolve, reject) => {
      fs.readFile( path, {
        encoding: 'utf8'
      }, (err, data) => {
        if (err) return reject(err)
        resolve(JSON.parse(data.toString()))
      })
    })
  }
}

module.exports = db
