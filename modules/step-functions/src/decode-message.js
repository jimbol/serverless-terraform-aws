module.exports.handler = async (data) => {
  const buff = new Buffer(data.encoded, 'base64');
  const text = buff.toString('ascii');
  return {
    decoded_id: data.encoded,
    decoded: text,
  }
}
