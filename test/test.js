const Ticket = artifacts.require('./TicketBookingSystem.sol')

require('chai')
  .use(require('chai-as-promised'))
  .should()

contract('Ticket', (_accounts) => {
  let contract

  before(async () => {
    contract = await Ticket.deployed()
  })

  describe('deployment', async () => {
    it('deploys successfully', async () => {
      const address = contract.address
      assert.notEqual(address, 0x0)
      assert.notEqual(address, '')
      assert.notEqual(address, null)
      assert.notEqual(address, undefined)
    })

    it('has a name', async () => {
      const name = await contract.name()
      assert.equal(name, 'ShowTicket')
    })

    it('has a symbol', async () => {
      const symbol = await contract.symbol()
      assert.equal(symbol, 'ST')
    })
  })
})
