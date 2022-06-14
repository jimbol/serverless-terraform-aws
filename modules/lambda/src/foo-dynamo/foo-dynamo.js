const AWS = require("aws-sdk"); // using the SDK
const TABLE = 'Blog';

const documentClient = new AWS.DynamoDB.DocumentClient();

module.exports.handler = async (event, context) => {
 // create a new object

  const body = event.body;

  const newNote = {
    postId: `${Date.now()}`,
    body: 'here is my blog body'
  };

  await documentClient
  .put({
    TableName: TABLE,
    Item: newNote,
  })
  .promise();


  const allPosts = await documentClient
  .scan({
    TableName: TABLE,
  }).promise();

  const { Items = [] } = allPosts;
  return {
    statusCode: 200,
    body: JSON.stringify(Items),
  };
};
