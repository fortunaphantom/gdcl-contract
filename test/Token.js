const { expect } = require('chai');
const { ethers } = require('hardhat');
const keccak256 = require('keccak256');
const { MerkleTree } = require('merkletreejs')

let owner;
let freeMintAddrs = [];
let preSaleAddrs = [];
let publicSaleAddrs = [];
let token;

let provider = ethers.getDefaultProvider();

function getMerkleData(address, arr) {
  const leaves = arr.map((v) => keccak256(v.toLowerCase()))
  const tree = new MerkleTree(leaves, keccak256, { sort: true })
  const root = tree.getHexRoot()
  const leaf = keccak256(address)
  const proof = tree.getHexProof(leaf)
  const verified = tree.verify(proof, leaf, root)
  return { root, proof, leaf, verified, address }
}

function getMerkleRoot(arr) {
  const leaves = arr.map((v) => keccak256(v.toLowerCase()))
  const tree = new MerkleTree(leaves, keccak256, { sort: true })
  return tree.getHexRoot()
}

beforeEach(async function () {
  [
    owner,
    freeMintAddrs[0], freeMintAddrs[1], freeMintAddrs[2], freeMintAddrs[3], freeMintAddrs[4], freeMintAddrs[5], freeMintAddrs[6],
    preSaleAddrs[0], preSaleAddrs[1], preSaleAddrs[2], preSaleAddrs[3], preSaleAddrs[4], preSaleAddrs[5], preSaleAddrs[6],
    publicSaleAddrs[0], publicSaleAddrs[1], publicSaleAddrs[2], publicSaleAddrs[3], publicSaleAddrs[4], publicSaleAddrs[5], publicSaleAddrs[6],
  ] = await ethers.getSigners();
  let Token = await ethers.getContractFactory('TheGoodDogClubLLC');
  token = await Token.deploy();
});

describe('Token contract', function () {
  it('Owner', async function () {
    expect(await token.owner()).to.equal(owner.address);
  });

  it('free mint test', async function () {
    await token.setMintStep(0);
    let merkleData = getMerkleData(freeMintAddrs[0].address, freeMintAddrs.map(e => e.address));
    await token.setMerkleRoot(merkleData.root);
    await expect(
      freeMintAddrs[0].sendTransaction({
        to: token.address,
        value: ethers.utils.parseEther('0'),
        data: token.mintFreeNormal(100, merkleData.proof),
      })
    ).to.be.revertedWith("mint count error !");

    merkleData = getMerkleData(freeMintAddrs[1].address, freeMintAddrs.map(e => e.address));
    await token.connect(freeMintAddrs[1]).mintFreeNormal(2, merkleData.proof, { value: ethers.utils.parseEther('0') });
  });

  it('presale mint test', async function () {
    await token.setMintStep(1);
    let merkleData = getMerkleData(preSaleAddrs[0].address, preSaleAddrs.map(e => e.address));
    await token.setMerkleRoot(merkleData.root);
    await expect(
      preSaleAddrs[0].sendTransaction({
        to: token.address,
        value: ethers.utils.parseEther('0'),
        data: token.mintPresale(100, merkleData.proof),
      })
    ).to.be.revertedWith("mint count error !");

    merkleData = getMerkleData(preSaleAddrs[1].address, preSaleAddrs.map(e => e.address));
    await expect(token.connect(preSaleAddrs[1]).mintPresale(2, merkleData.proof, { value: ethers.utils.parseEther('0') })).to.be.revertedWith("Price error !");
  });

  it('public mint test', async function () {
    await token.setMintStep(2);
    await expect(token.connect(publicSaleAddrs[1]).mintPublic(2, { value: ethers.utils.parseEther('0') })).to.be.revertedWith("Price error !");
  });
});
