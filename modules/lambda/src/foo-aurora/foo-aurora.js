const AWS = require("aws-sdk");
const rdsDataService = new AWS.RDSDataService()


exports.handler = async (event, context) => {
  let sqlParams = {
    secretArn: 'arn:aws:secretsmanager:us-east-2:425010903010:secret:AuroraDBPassword-o836Mt',
    resourceArn: 'arn:aws:rds:us-east-2:425010903010:cluster:dev-postgresql',
    sql: 'SELECT version();',
    database: 'postgres',
    includeResultMetadata: true
  }

  console.log('about to run');
  // run SQL command
  const result = await new Promise((resolve, reject) => {
    rdsDataService.executeStatement(sqlParams, function (err, data) {
      console.log('result received');
      if (err) {
        // error
        reject('Query Failed')
        console.log(err)
      } else {
        // done
        console.log('Found rows: ' + data)
        resolve(data)
      }
    })
  });

  return {
    statusCode: 200,
    body: JSON.stringify(result),
  };
}
